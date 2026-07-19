const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentUpdated, onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();
setGlobalOptions({region: "europe-west1"});

// ============ ORTAK YARDIMCI FONKSİYONLAR ============
const SUITS = ["spades", "hearts", "diamonds", "clubs"];
const RANKS = [
  "two", "three", "four", "five", "six", "seven", "eight",
  "nine", "ten", "jack", "queen", "king", "ace",
];
const RANK_VALUE = Object.fromEntries(RANKS.map((r, i) => [r, i]));

function buildDeck() {
  const deck = [];
  for (const suit of SUITS) {
    for (const rank of RANKS) deck.push({suit, rank});
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

// ============ PİŞTİ MANTIĞI ============

function pistiCalculateScores(order, collectedCards, pistiCounts) {
  const scores = {};
  order.forEach((id) => { scores[id] = 0; });
  order.forEach((id) => { scores[id] += (pistiCounts[id] || 0) * 10; });

  let mostCardsPlayer = null; let mostCards = -1;
  order.forEach((id) => {
    const count = (collectedCards[id] || []).length;
    if (count > mostCards) { mostCards = count; mostCardsPlayer = id; }
  });
  if (mostCardsPlayer) scores[mostCardsPlayer] += 3;

  let mostClubsPlayer = null; let mostClubs = -1;
  order.forEach((id) => {
    const count = (collectedCards[id] || []).filter((c) => c.suit === "clubs").length;
    if (count > mostClubs) { mostClubs = count; mostClubsPlayer = id; }
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

async function initPistiGame(roomId, playerOrder) {
  const deck = shuffle(buildDeck());
  const hands = {};
  for (const uid of playerOrder) hands[uid] = deck.splice(0, 4);
  const tableCards = deck.splice(0, 4);

  const batch = db.batch();
  for (const uid of playerOrder) {
    batch.set(db.doc(`rooms/${roomId}/hands/${uid}`), {cards: hands[uid]});
  }
  batch.set(db.doc(`rooms/${roomId}/gameState/public`), {
    gameType: "pisti",
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
}

async function handlePistiMove(roomId, playerId, cardPlayed, moveRef) {
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
    if (!hand.some((c) => cardsEqual(c, cardPlayed))) {
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
      tableCards, currentTurnPlayerId: nextPlayerId,
      pistiCounts, handCounts, lastCollectorId,
    });
    tx.update(privateRef, {collectedCards});
    tx.update(moveRef, {status: "applied"});
  });

  await maybeDealNextPistiRoundOrFinish(roomId);
}

async function maybeDealNextPistiRoundOrFinish(roomId) {
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
    order.forEach((id, i) => { hands[id] = handSnaps[i].data()?.cards || []; });

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
        ...(collectedCards[pub.lastCollectorId] || []), ...tableCards,
      ];
      tableCards = [];
    }

    const scores = pistiCalculateScores(order, collectedCards, pub.pistiCounts);

    tx.update(publicRef, {tableCards, status: "finished", scores});
    tx.update(privateRef, {collectedCards});
    tx.update(db.doc(`rooms/${roomId}`), {status: "finished"});
  });
}

// ============ BATAK MANTIĞI ============

const MIN_BID = 5;
const MAX_BID = 13;

function batakDetermineTrickWinner(trick, trumpSuit) {
  const ledSuit = trick[0].card.suit;
  const trumpCards = trumpSuit ? trick.filter((t) => t.card.suit === trumpSuit) : [];

  if (trumpCards.length > 0) {
    trumpCards.sort((a, b) => RANK_VALUE[b.card.rank] - RANK_VALUE[a.card.rank]);
    return trumpCards[0].playerId;
  }

  const ledSuitCards = trick.filter((t) => t.card.suit === ledSuit);
  ledSuitCards.sort((a, b) => RANK_VALUE[b.card.rank] - RANK_VALUE[a.card.rank]);
  return ledSuitCards[0].playerId;
}

function batakCalculateScores(order, declarerId, highestBid, tricksWon) {
  const scores = {};
  order.forEach((id) => { scores[id] = 0; });
  if (!declarerId) return scores;

  const declarerTricks = tricksWon[declarerId] || 0;
  scores[declarerId] = declarerTricks >= highestBid ? highestBid * 10 : -(highestBid * 10);

  order.forEach((id) => {
    if (id === declarerId) return;
    const tricks = tricksWon[id] || 0;
    if (tricks > 0) {
      scores[id] = tricks * 10;
    } else {
      scores[id] = -(highestBid * 10);
    }
  });

  return scores;
}

async function initBatakGame(roomId, playerOrder) {
  if (playerOrder.length !== 4) return; // batak tam 4 oyuncu gerektirir

  const deck = shuffle(buildDeck());
  const hands = {};
  for (const uid of playerOrder) hands[uid] = deck.splice(0, 13);

  const dealerId = playerOrder[0];
  const firstBidderIndex = (playerOrder.indexOf(dealerId) + 1) % playerOrder.length;

  const batch = db.batch();
  for (const uid of playerOrder) {
    batch.set(db.doc(`rooms/${roomId}/hands/${uid}`), {cards: hands[uid]});
  }
  batch.set(db.doc(`rooms/${roomId}/gameState/public`), {
    gameType: "batak",
    phase: "bidding",
    playerOrder,
    dealerId,
    bids: {},
    passedPlayers: [],
    highestBidderId: null,
    highestBid: 0,
    currentTurnPlayerId: playerOrder[firstBidderIndex],
    trumpSuit: null,
    declarerId: null,
    currentTrick: [],
    trickLeaderId: null,
    tricksWon: Object.fromEntries(playerOrder.map((id) => [id, 0])),
    handCounts: Object.fromEntries(playerOrder.map((id) => [id, 13])),
    status: "playing",
  });
  await batch.commit();
}

function batakNextActiveBidder(order, fromPlayerId, passedPlayers) {
  const startIndex = order.indexOf(fromPlayerId);
  for (let offset = 1; offset < order.length; offset++) {
    const candidate = order[(startIndex + offset) % order.length];
    if (!passedPlayers.includes(candidate)) return candidate;
  }
  return null;
}

async function handleBatakMove(roomId, playerId, move, moveRef) {
  const publicRef = db.doc(`rooms/${roomId}/gameState/public`);
  const handRef = db.doc(`rooms/${roomId}/hands/${playerId}`);

  await db.runTransaction(async (tx) => {
    const publicSnap = await tx.get(publicRef);
    if (!publicSnap.exists) {
      tx.update(moveRef, {status: "rejected", reason: "oyun-durumu-bulunamadi"});
      return;
    }
    const pub = publicSnap.data();

    if (pub.currentTurnPlayerId !== playerId) {
      tx.update(moveRef, {status: "rejected", reason: "sira-sende-degil"});
      return;
    }

    if (move.type === "bid") {
      if (pub.phase !== "bidding") {
        tx.update(moveRef, {status: "rejected", reason: "ihale-fazi-degil"});
        return;
      }
      const amount = move.bidAmount;
      if (amount < MIN_BID || amount > MAX_BID || amount <= pub.highestBid) {
        tx.update(moveRef, {status: "rejected", reason: "gecersiz-teklif"});
        return;
      }

      const newBids = {...pub.bids, [playerId]: amount};
      const nextTurn = batakNextActiveBidder(pub.playerOrder, playerId, pub.passedPlayers);

      if (nextTurn === null) {
        tx.update(publicRef, {
          bids: newBids, highestBidderId: playerId, highestBid: amount,
          phase: "chooseTrump", declarerId: playerId, currentTurnPlayerId: playerId,
        });
      } else {
        tx.update(publicRef, {
          bids: newBids, highestBidderId: playerId, highestBid: amount,
          currentTurnPlayerId: nextTurn,
        });
      }
      tx.update(moveRef, {status: "applied"});
      return;
    }

    if (move.type === "pass") {
      if (pub.phase !== "bidding") {
        tx.update(moveRef, {status: "rejected", reason: "ihale-fazi-degil"});
        return;
      }
      const newPassed = [...pub.passedPlayers, playerId];
      const activeCount = pub.playerOrder.length - newPassed.length;

      if (activeCount === 0 && !pub.highestBidderId) {
        tx.update(publicRef, {
          passedPlayers: newPassed, highestBidderId: pub.dealerId, highestBid: MIN_BID,
          phase: "chooseTrump", declarerId: pub.dealerId, currentTurnPlayerId: pub.dealerId,
        });
      } else if (activeCount <= 1 && pub.highestBidderId) {
        tx.update(publicRef, {
          passedPlayers: newPassed, phase: "chooseTrump",
          declarerId: pub.highestBidderId, currentTurnPlayerId: pub.highestBidderId,
        });
      } else {
        const nextTurn = batakNextActiveBidder(pub.playerOrder, playerId, newPassed);
        tx.update(publicRef, {
          passedPlayers: newPassed,
          currentTurnPlayerId: nextTurn || pub.highestBidderId || pub.dealerId,
        });
      }
      tx.update(moveRef, {status: "applied"});
      return;
    }

    if (move.type === "chooseTrump") {
      if (pub.phase !== "chooseTrump" || pub.declarerId !== playerId) {
        tx.update(moveRef, {status: "rejected", reason: "koz-secemezsin"});
        return;
      }
      tx.update(publicRef, {
        trumpSuit: move.trumpSuit, phase: "playing",
        currentTurnPlayerId: playerId, trickLeaderId: playerId,
      });
      tx.update(moveRef, {status: "applied"});
      return;
    }

    if (move.type === "playCard") {
      if (pub.phase !== "playing") {
        tx.update(moveRef, {status: "rejected", reason: "oyun-fazi-degil"});
        return;
      }
      const handSnap = await tx.get(handRef);
      const hand = handSnap.data()?.cards || [];
      const card = move.card;

      if (!hand.some((c) => cardsEqual(c, card))) {
        tx.update(moveRef, {status: "rejected", reason: "kart-elde-yok"});
        return;
      }

      if (pub.currentTrick.length > 0) {
        const ledSuit = pub.currentTrick[0].card.suit;
        const hasLedSuit = hand.some((c) => c.suit === ledSuit);
        if (hasLedSuit) {
          if (card.suit !== ledSuit) {
            tx.update(moveRef, {status: "rejected", reason: "renk-takip-zorunlu"});
            return;
          }
          // Yerdeki en yüksek ledSuit kartını geçmek zorunlu (kart yükseltme)
          let highestLedCard = null;
          for (const tc of pub.currentTrick) {
            if (tc.card.suit === ledSuit) {
              if (!highestLedCard || RANK_VALUE[tc.card.rank] > RANK_VALUE[highestLedCard.rank]) {
                highestLedCard = tc.card;
              }
            }
          }
          if (highestLedCard) {
            const hasHigherLed = hand.some((c) => c.suit === ledSuit && RANK_VALUE[c.rank] > RANK_VALUE[highestLedCard.rank]);
            if (hasHigherLed && RANK_VALUE[card.rank] <= RANK_VALUE[highestLedCard.rank]) {
              tx.update(moveRef, {status: "rejected", reason: "kart-yukseltmek-zorunlu"});
              return;
            }
          }
        } else {
          // Renk takip yok, koz çakma durumları
          const trumpSuit = pub.trumpSuit;
          if (trumpSuit) {
            const trumpCards = hand.filter((c) => c.suit === trumpSuit);
            if (trumpCards.length > 0) {
              // Yerdeki en büyük kozu bul
              let highestTrumpCard = null;
              for (const tc of pub.currentTrick) {
                if (tc.card.suit === trumpSuit) {
                  if (!highestTrumpCard || RANK_VALUE[tc.card.rank] > RANK_VALUE[highestTrumpCard.rank]) {
                    highestTrumpCard = tc.card;
                  }
                }
              }

              // Elinde koz varken koz oynamak zorundasın
              if (card.suit !== trumpSuit) {
                tx.update(moveRef, {status: "rejected", reason: "koz-atmak-zorunlu"});
                return;
              }

              if (highestTrumpCard) {
                const hasHigherTrump = trumpCards.some((c) => RANK_VALUE[c.rank] > RANK_VALUE[highestTrumpCard.rank]);
                if (hasHigherTrump) {
                  // Daha büyük kozun varsa, onu geçmek zorundasın.
                  if (RANK_VALUE[card.rank] <= RANK_VALUE[highestTrumpCard.rank]) {
                    tx.update(moveRef, {status: "rejected", reason: "daha-buyuk-koz-atmak-zorunlu"});
                    return;
                  }
                }
              }
            }
          }
        }
      }

      const newHand = [...hand];
      removeCard(newHand, card);
      const newTrick = [...pub.currentTrick, {playerId, card}];
      const handCounts = {...pub.handCounts, [playerId]: newHand.length};

      tx.update(handRef, {cards: newHand});

      if (newTrick.length < pub.playerOrder.length) {
        const nextIndex = (pub.playerOrder.indexOf(playerId) + 1) % pub.playerOrder.length;
        tx.update(publicRef, {
          currentTrick: newTrick, handCounts,
          currentTurnPlayerId: pub.playerOrder[nextIndex],
        });
        tx.update(moveRef, {status: "applied"});
        return;
      }

      // Trick tamamlandı
      const winnerId = batakDetermineTrickWinner(newTrick, pub.trumpSuit);
      const newTricksWon = {...pub.tricksWon, [winnerId]: (pub.tricksWon[winnerId] || 0) + 1};
      const allHandsEmpty = Object.values(handCounts).every((c) => c === 0);

      if (allHandsEmpty) {
        const scores = batakCalculateScores(
            pub.playerOrder, pub.declarerId, pub.highestBid, newTricksWon,
        );
        tx.update(publicRef, {
          currentTrick: [], handCounts, tricksWon: newTricksWon,
          trickLeaderId: winnerId, currentTurnPlayerId: winnerId,
          phase: "finished", status: "finished", scores,
        });
        tx.update(db.doc(`rooms/${roomId}`), {status: "finished"});
      } else {
        tx.update(publicRef, {
          currentTrick: [], handCounts, tricksWon: newTricksWon,
          trickLeaderId: winnerId, currentTurnPlayerId: winnerId,
        });
      }
      tx.update(moveRef, {status: "applied"});
    }
  });
}

// ============ FIRESTORE TETİKLEYİCİLERİ ============

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
  const gameType = after.gameType || "pisti";

  if (gameType === "batak") {
    if (playerOrder.length < 4) return;
    await initBatakGame(roomId, playerOrder);
  } else {
    if (playerOrder.length < 2) return;
    await initPistiGame(roomId, playerOrder);
  }
});

exports.onMoveCreated = onDocumentCreated("rooms/{roomId}/moves/{moveId}", async (event) => {
  const roomId = event.params.roomId;
  const moveData = event.data.data();
  const playerId = moveData.playerId;
  const moveRef = event.data.ref;

  const publicSnap = await db.doc(`rooms/${roomId}/gameState/public`).get();
  const gameType = publicSnap.exists ? (publicSnap.data().gameType || "pisti") : "pisti";

  if (gameType === "batak") {
    await handleBatakMove(roomId, playerId, moveData, moveRef);
  } else {
    await handlePistiMove(roomId, playerId, moveData.card, moveRef);
  }
});