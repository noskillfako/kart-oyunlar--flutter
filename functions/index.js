const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentUpdated, onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Firestore veritabanı europe-west bölgesinde olduğu için fonksiyonları da
// aynı bölgede çalıştırıyoruz.
setGlobalOptions({region: "europe-west1"});

// ---- Kart yardımcı fonksiyonları ----
const SUITS = ["spades", "hearts", "diamonds", "clubs"];
const RANKS = [
  "two", "three", "four", "five", "six", "seven", "eight",
  "nine", "ten", "jack", "queen", "king", "ace",
];

function buildDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) {
      deck.push({suit, rank});
    }
  }
  return deck;
}

function shuffle(deck) {
  for (let i = deck.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [deck[i], deck[j]] = [deck[j], deck[i]];
  }
  return deck;
}

function cardsEqual(a, b) {
  return a.suit === b.suit && a.rank === b.rank;
}

function removeCard(hand, card) {
  const idx = hand.findIndex((c) => cardsEqual(c, card));
  if (idx === -1) return false;
  hand.splice(idx, 1);
  return true;
}

function calculateScores(order, collectedCards, pistiCounts) {
  const scores = {};
  order.forEach((id) => {
    scores[id] = 0;
  });

  order.forEach((id) => {
    scores[id] += (pistiCounts[id] || 0) * 10;
  });

  let mostCardsPlayer = null;
  let mostCards = -1;
  order.forEach((id) => {
    const count = (collectedCards[id] || []).length;
    if (count > mostCards) {
      mostCards = count;
      mostCardsPlayer = id;
    }
  });
  if (mostCardsPlayer) scores[mostCardsPlayer] += 3;

  let mostClubsPlayer = null;
  let mostClubs = -1;
  order.forEach((id) => {
    const count = (collectedCards[id] || []).filter((c) => c.suit === "clubs").length;
    if (count > mostClubs) {
      mostClubs = count;
      mostClubsPlayer = id;
    }
  });
  if (mostClubsPlayer) scores[mostClubsPlayer] += 1;

  order.forEach((id) => {
    const hasDiamondTen = (collectedCards[id] || []).some(
        (c) => c.suit === "diamonds" && c.rank === "ten",
    );
    if (hasDiamondTen) scores[id] += 3;
  });

  order.forEach((id) => {
    const bonusCards = (collectedCards[id] || []).filter(
        (c) => c.rank === "ace" || c.rank === "jack",
    ).length;
    scores[id] += bonusCards;
  });

  return scores;
}

// ---- 1) Oda "playing" durumuna geçince oyunu başlatır ----
exports.onRoomStatusChange = onDocumentUpdated("rooms/{roomId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const roomId = event.params.roomId;

  if (before.status === after.status) return;
  if (after.status !== "playing") return;

  const publicRef = db.doc(`rooms/${roomId}/gameState/public`);
  const publicSnap = await publicRef.get();
  if (publicSnap.exists) return;

  const playerOrder = Object.keys(after.players || {});
  if (playerOrder.length < 2) return;

  const deck = shuffle(buildDeck());
  const hands = {};
  for (const uid of playerOrder) {
    hands[uid] = deck.splice(0, 4);
  }
  const tableCards = deck.splice(0, 4);

  const batch = db.batch();

  for (const uid of playerOrder) {
    batch.set(db.doc(`rooms/${roomId}/hands/${uid}`), {cards: hands[uid]});
  }

  batch.set(publicRef, {
    tableCards,
    currentTurnPlayerId: playerOrder[0],
    playerOrder,
    handCounts: Object.fromEntries(playerOrder.map((id) => [id, 4])),
    pistiCounts: Object.fromEntries(playerOrder.map((id) => [id, 0])),
    lastCollectorId: null,
    deckCount: deck.length,
    status: "playing",
  });

  batch.set(db.doc(`rooms/${roomId}/gameState/private`), {
    deck,
    collectedCards: Object.fromEntries(playerOrder.map((id) => [id, []])),
  });

  await batch.commit();
});

// ---- 2) Bir hamle isteği oluşunca işler ----
exports.onMoveCreated = onDocumentCreated("rooms/{roomId}/moves/{moveId}", async (event) => {
  const roomId = event.params.roomId;
  const moveData = event.data.data();
  const playerId = moveData.playerId;
  const cardPlayed = moveData.card;
  const moveRef = event.data.ref;

  const publicRef = db.doc(`rooms/${roomId}/gameState/public`);
  const privateRef = db.doc(`rooms/${roomId}/gameState/private`);
  const handRef = db.doc(`rooms/${roomId}/hands/${playerId}`);

  await db.runTransaction(async (tx) => {
    const [publicSnap, privateSnap, handSnap] = await Promise.all([
      tx.get(publicRef), tx.get(privateRef), tx.get(handRef),
    ]);

    if (!publicSnap.exists || !privateSnap.exists || !handSnap.exists) {
      tx.update(moveRef, {status: "rejected", reason: "oyun-durumu-bulunamadi"});
      return;
    }

    const pub = publicSnap.data();
    const priv = privateSnap.data();
    const hand = handSnap.data().cards || [];

    if (pub.status !== "playing") {
      tx.update(moveRef, {status: "rejected", reason: "oyun-aktif-degil"});
      return;
    }
    if (pub.currentTurnPlayerId !== playerId) {
      tx.update(moveRef, {status: "rejected", reason: "sira-sende-degil"});
      return;
    }
    const handHasCard = hand.some((c) => cardsEqual(c, cardPlayed));
    if (!handHasCard) {
      tx.update(moveRef, {status: "rejected", reason: "kart-elde-yok"});
      return;
    }

    const newHand = [...hand];
    removeCard(newHand, cardPlayed);

    let tableCards = [...pub.tableCards];
    const collectedCards = {...priv.collectedCards};
    collectedCards[playerId] = [...(collectedCards[playerId] || [])];
    const pistiCounts = {...pub.pistiCounts};
    const handCounts = {...pub.handCounts};

    const tableWasSingle = tableCards.length === 1;
    const topCard = tableCards.length > 0 ? tableCards[tableCards.length - 1] : null;
    const isJack = cardPlayed.rank === "jack";
    const isMatch = !!topCard && topCard.rank === cardPlayed.rank;

    let lastCollectorId = pub.lastCollectorId || null;

    if (tableCards.length > 0 && (isJack || isMatch)) {
      collectedCards[playerId].push(...tableCards, cardPlayed);
      lastCollectorId = playerId;
      if (isMatch && tableWasSingle) {
        pistiCounts[playerId] = (pistiCounts[playerId] || 0) + 1;
      }
      tableCards = [];
    } else {
      tableCards.push(cardPlayed);
    }

    const order = pub.playerOrder;
    const idx = order.indexOf(playerId);
    const nextPlayerId = order[(idx + 1) % order.length];
    handCounts[playerId] = newHand.length;

    tx.update(handRef, {cards: newHand});
    tx.update(publicRef, {
      tableCards,
      currentTurnPlayerId: nextPlayerId,
      pistiCounts,
      handCounts,
      lastCollectorId,
    });
    tx.update(privateRef, {collectedCards});
    tx.update(moveRef, {status: "applied"});
  });

  await maybeDealNextRoundOrFinish(roomId);
});

// ---- Yardımcı: tüm eller boşaldıysa yeni tur dağıt ya da oyunu bitir ----
async function maybeDealNextRoundOrFinish(roomId) {
  const publicRef = db.doc(`rooms/${roomId}/gameState/public`);
  const privateRef = db.doc(`rooms/${roomId}/gameState/private`);

  await db.runTransaction(async (tx) => {
    const pubSnap = await tx.get(publicRef);
    const privSnap = await tx.get(privateRef);
    if (!pubSnap.exists || !privSnap.exists) return;

    const pub = pubSnap.data();
    const priv = privSnap.data();
    const order = pub.playerOrder;

    const handSnaps = await Promise.all(
        order.map((id) => tx.get(db.doc(`rooms/${roomId}/hands/${id}`))),
    );
    const hands = {};
    order.forEach((id, i) => {
      hands[id] = handSnaps[i].data()?.cards || [];
    });

    const allHandsEmpty = order.every((id) => hands[id].length === 0);
    if (!allHandsEmpty) return;

    let deck = [...priv.deck];

    if (deck.length > 0) {
      const handCounts = {...pub.handCounts};
      for (const id of order) {
        const drawn = deck.splice(0, Math.min(4, deck.length));
        tx.update(db.doc(`rooms/${roomId}/hands/${id}`), {cards: drawn});
        handCounts[id] = drawn.length;
      }
      tx.update(publicRef, {deckCount: deck.length, handCounts});
      tx.update(privateRef, {deck});
      return;
    }

    let tableCards = [...pub.tableCards];
    const collectedCards = {...priv.collectedCards};
    if (tableCards.length > 0 && pub.lastCollectorId) {
      collectedCards[pub.lastCollectorId] = [
        ...(collectedCards[pub.lastCollectorId] || []),
        ...tableCards,
      ];
      tableCards = [];
    }

    const scores = calculateScores(order, collectedCards, pub.pistiCounts);

    tx.update(publicRef, {
      tableCards,
      status: "finished",
      scores,
    });
    tx.update(privateRef, {collectedCards});
    tx.update(db.doc(`rooms/${roomId}`), {status: "finished"});
  });
}