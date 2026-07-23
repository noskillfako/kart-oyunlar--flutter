const {setGlobalOptions} = require("firebase-functions/v2");
const {onDocumentUpdated, onDocumentCreated, onDocumentDeleted} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");

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

async function initPistiGame(roomId, playerOrder, totalRounds) {
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
    collectedCardCounts: Object.fromEntries(playerOrder.map((id) => [id, 0])),
    currentScores: Object.fromEntries(playerOrder.map((id) => [id, 0])),
    cumulativeScores: Object.fromEntries(playerOrder.map((id) => [id, 0])),
    roundHistory: [],
    roundReady: Object.fromEntries(playerOrder.map((id) => [id, false])),
    currentRound: 1,
    totalRounds: totalRounds || 1,
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
    const collectedCardCounts = {...pub.collectedCardCounts};

    const tableWasSingle = tableCards.length === 1;
    const topCard = tableCards.length > 0 ? tableCards[tableCards.length - 1] : null;
    const isJack = cardPlayed.rank === "jack";
    const isMatch = !!topCard && topCard.rank === cardPlayed.rank;
    let lastCollectorId = pub.lastCollectorId || null;

    if (tableCards.length > 0 && (isJack || isMatch)) {
      collectedCards[playerId].push(...tableCards, cardPlayed);
      collectedCardCounts[playerId] = (collectedCardCounts[playerId] || 0) + tableCards.length + 1;
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

    // Calculate current scores dynamically based on the current collected cards & pistis
    const currentScores = pistiCalculateScores(order, collectedCards, pistiCounts);

    tx.update(handRef, {cards: newHand});
    tx.update(publicRef, {
      tableCards, currentTurnPlayerId: nextPlayerId,
      pistiCounts, handCounts, lastCollectorId,
      collectedCardCounts, currentScores,
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
    const collectedCardCounts = {...pub.collectedCardCounts};
    if (tableCards.length > 0 && pub.lastCollectorId) {
      collectedCards[pub.lastCollectorId] = [
        ...(collectedCards[pub.lastCollectorId] || []), ...tableCards,
      ];
      collectedCardCounts[pub.lastCollectorId] = (collectedCardCounts[pub.lastCollectorId] || 0) + tableCards.length;
      tableCards = [];
    }

    const scores = pistiCalculateScores(order, collectedCards, pub.pistiCounts);

    const cumulativeScores = {...pub.cumulativeScores};
    order.forEach((id) => {
      cumulativeScores[id] = (cumulativeScores[id] || 0) + (scores[id] || 0);
    });

    const roundHistory = [...(pub.roundHistory || [])];
    roundHistory.push({
      round: pub.currentRound,
      scores: scores,
    });

    const isLastRound = pub.currentRound >= pub.totalRounds;

    if (isLastRound) {
      const botSeats = pub.botControlledSeats || [];
      const realPlayers = order.filter((id) => !botSeats.includes(id));
      const rankingSource = realPlayers.length > 0 ? realPlayers : order;
      const finalRanking = [...rankingSource].sort((a, b) => (cumulativeScores[b] || 0) - (cumulativeScores[a] || 0));

      tx.update(publicRef, {
        tableCards,
        status: "matchFinished",
        scores,
        collectedCardCounts,
        currentScores: scores,
        cumulativeScores,
        roundHistory,
        finalRanking,
      });
      tx.update(privateRef, {collectedCards});
      tx.update(db.doc(`rooms/${roomId}`), {status: "finished"});
    } else {
      tx.update(publicRef, {
        tableCards,
        status: "roundFinished",
        scores,
        collectedCardCounts,
        currentScores: scores,
        cumulativeScores,
        roundHistory,
        roundReady: Object.fromEntries(order.map((id) => [id, false])),
      });
      tx.update(privateRef, {collectedCards});
    }
  });
}

// ============ BATAK MANTIĞI ============

const MIN_BID = 7;    // Minimum ihale miktarı (demo ile aynı)
const FORCED_BID = 6; // Herkes pas geçerse zorunlu ihale (demo ile aynı)
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

async function initBatakGame(roomId, playerOrder, totalRounds) {
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
    trumpBroken: false,   // Koz kırılma durumu (demo ile aynı)
    declarerId: null,
    currentTrick: [],
    trickLeaderId: null,
    tricksWon: Object.fromEntries(playerOrder.map((id) => [id, 0])),
    handCounts: Object.fromEntries(playerOrder.map((id) => [id, 13])),
    cumulativeScores: Object.fromEntries(playerOrder.map((id) => [id, 0])),
    roundHistory: [],
    roundReady: Object.fromEntries(playerOrder.map((id) => [id, false])),
    currentRound: 1,
    totalRounds: totalRounds || 1,
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
        // Herkes pas geçti: dağıtıcının solundaki oyuncuya FORCED_BID (6) kalır (demo ile aynı)
        const dealerIndex = pub.playerOrder.indexOf(pub.dealerId);
        const firstBidderId = pub.playerOrder[(dealerIndex + 1) % pub.playerOrder.length];
        tx.update(publicRef, {
          passedPlayers: newPassed,
          highestBidderId: firstBidderId,
          highestBid: FORCED_BID,
          phase: "chooseTrump",
          declarerId: firstBidderId,
          currentTurnPlayerId: firstBidderId,
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

      const trumpSuit = pub.trumpSuit;
      const trumpBroken = pub.trumpBroken || false;

      if (pub.currentTrick.length === 0) {
        // ── YENİ EL AÇMA ──
        // Koz kırılmadan koz ile el açılamaz; elde başka renk varsa koz atma yasak (demo ile aynı)
        if (trumpSuit && card.suit === trumpSuit && !trumpBroken) {
          const hasOtherSuits = hand.some((c) => c.suit !== trumpSuit);
          if (hasOtherSuits) {
            tx.update(moveRef, {status: "rejected", reason: "koz-kirilmadan-koz-atamazsin"});
            return;
          }
        }
      } else {
        // ── MEVCUT ELE KART EKLEME ──
        const ledSuit = pub.currentTrick[0].card.suit;
        const hasLedSuit = hand.some((c) => c.suit === ledSuit);

        if (hasLedSuit) {
          // Renk takip zorunluluğu — o renkte herhangi bir kartı oynayabilirsin
          if (card.suit !== ledSuit) {
            tx.update(moveRef, {status: "rejected", reason: "renk-takip-zorunlu"});
            return;
          }
          // Kart yükseltme: trick'te koz yoksa büyük oynamak zorunlu
          const trumpInTrick = trumpSuit
            ? pub.currentTrick.some((tc) => tc.card.suit === trumpSuit)
            : false;
          if (!trumpInTrick) {
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
          }
          // NOT: Kart yükseltme zorunluluğu standart Batak kuralı değildir, kaldırıldı.
        } else {
          // Renk yoksa → koz çakma durumları (demo ile aynı)
          if (trumpSuit) {
            const trumpCards = hand.filter((c) => c.suit === trumpSuit);
            if (trumpCards.length > 0) {
              // Elinde koz varken başka renk atamazsın
              if (card.suit !== trumpSuit) {
                tx.update(moveRef, {status: "rejected", reason: "koz-atmak-zorunlu"});
                return;
              }
              // Yerdeki en büyük kozu bul
              let highestTrumpCard = null;
              for (const tc of pub.currentTrick) {
                if (tc.card.suit === trumpSuit) {
                  if (!highestTrumpCard || RANK_VALUE[tc.card.rank] > RANK_VALUE[highestTrumpCard.rank]) {
                    highestTrumpCard = tc.card;
                  }
                }
              }
              if (highestTrumpCard) {
                // Yerde zaten koz var; daha büyük kozun varsa onu geçmek zorundasın
                const hasHigherTrump = trumpCards.some((c) => RANK_VALUE[c.rank] > RANK_VALUE[highestTrumpCard.rank]);
                if (hasHigherTrump && RANK_VALUE[card.rank] <= RANK_VALUE[highestTrumpCard.rank]) {
                  tx.update(moveRef, {status: "rejected", reason: "daha-buyuk-koz-atmak-zorunlu"});
                  return;
                }
              }
              // highestTrumpCard === null → yerde henüz koz yok, ilk çakışı yapıyorsun (geçerli)
            }
          }
        }
      }

      const newHand = [...hand];
      removeCard(newHand, card);
      const newTrick = [...pub.currentTrick, {playerId, card}];
      const handCounts = {...pub.handCounts, [playerId]: newHand.length};

      // Koz kırılma takibi: oynanan kart kozsa trumpBroken true olur (demo ile aynı)
      const newTrumpBroken = trumpBroken || (trumpSuit && card.suit === trumpSuit);

      tx.update(handRef, {cards: newHand});

      if (newTrick.length < pub.playerOrder.length) {
        const nextIndex = (pub.playerOrder.indexOf(playerId) + 1) % pub.playerOrder.length;
        tx.update(publicRef, {
          currentTrick: newTrick, handCounts, trumpBroken: newTrumpBroken,
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

        const cumulativeScores = {...pub.cumulativeScores};
        pub.playerOrder.forEach((id) => {
          cumulativeScores[id] = (cumulativeScores[id] || 0) + (scores[id] || 0);
        });

        const roundHistory = [...(pub.roundHistory || [])];
        roundHistory.push({
          round: pub.currentRound,
          scores: scores,
        });

        const isLastRound = pub.currentRound >= pub.totalRounds;

        if (isLastRound) {
          const botSeats = pub.botControlledSeats || [];
          const realPlayers = pub.playerOrder.filter((id) => !botSeats.includes(id));
          const rankingSource = realPlayers.length > 0 ? realPlayers : pub.playerOrder;
          const finalRanking = [...rankingSource].sort((a, b) => (cumulativeScores[b] || 0) - (cumulativeScores[a] || 0));

          tx.update(publicRef, {
            currentTrick: [], handCounts, tricksWon: newTricksWon,
            trickLeaderId: winnerId, currentTurnPlayerId: winnerId,
            trumpBroken: newTrumpBroken,
            phase: "finished",
            status: "matchFinished",
            scores,
            cumulativeScores,
            roundHistory,
            finalRanking,
          });
          tx.update(db.doc(`rooms/${roomId}`), {status: "finished"});
        } else {
          tx.update(publicRef, {
            currentTrick: [], handCounts, tricksWon: newTricksWon,
            trickLeaderId: winnerId, currentTurnPlayerId: winnerId,
            trumpBroken: newTrumpBroken,
            phase: "finished",
            status: "roundFinished",
            scores,
            cumulativeScores,
            roundHistory,
            roundReady: Object.fromEntries(pub.playerOrder.map((id) => [id, false])),
          });
        }
      } else {
        tx.update(publicRef, {
          currentTrick: [], handCounts, tricksWon: newTricksWon,
          trickLeaderId: winnerId, currentTurnPlayerId: winnerId,
          trumpBroken: newTrumpBroken,
        });
      }
      tx.update(moveRef, {status: "applied"});
    }
  });
}

// ============ FIRESTORE TETİKLEYİCİLERİ ============

/**
 * Bir collection'daki tüm document'ları siler.
 */
async function deleteCollection(colRef, batchSize = 50) {
  const snap = await colRef.limit(batchSize).get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  if (snap.size === batchSize) await deleteCollection(colRef, batchSize);
}

/**
 * Oda ve tüm alt-koleksiyonlarını siler.
 */
async function deleteRoom(roomId) {
  // Alt koleksiyonları sil
  await deleteCollection(db.collection(`rooms/${roomId}/gameState`));
  await deleteCollection(db.collection(`rooms/${roomId}/hands`));
  await deleteCollection(db.collection(`rooms/${roomId}/moves`));
  // Oda belgesini sil
  await db.doc(`rooms/${roomId}`).delete();
  console.log(`Oda silindi: ${roomId}`);
}

async function handleRoundReadyMove(roomId, playerId, moveRef) {
  const publicRef = db.doc(`rooms/${roomId}/gameState/public`);
  const privateRef = db.doc(`rooms/${roomId}/gameState/private`);

  await db.runTransaction(async (tx) => {
    const [publicSnap, privateSnap] = await Promise.all([
      tx.get(publicRef), tx.get(privateRef),
    ]);
    if (!publicSnap.exists) {
      tx.update(moveRef, {status: "rejected", reason: "oyun-durumu-bulunamadi"});
      return;
    }

    const pub = publicSnap.data();
    if (pub.status !== "roundFinished") {
      tx.update(moveRef, {status: "rejected", reason: "oyun-tur-bitisinde-degil"});
      return;
    }

    const roundReady = {...pub.roundReady};
    roundReady[playerId] = true;

    const allReady = pub.playerOrder.every((id) => roundReady[id] === true);

    if (allReady) {
      const nextRound = pub.currentRound + 1;
      const deck = shuffle(buildDeck());
      const playerOrder = pub.playerOrder;

      // Geri dönen oyuncuları bota devredilen koltuklardan çıkar (son 30s içinde presence gönderenler)
      let botControlledSeats = [...(pub.botControlledSeats || [])];
      if (botControlledSeats.length > 0) {
        const now = Date.now();
        const activeSeats = [];
        for (const uid of botControlledSeats) {
          const presSnap = await db.doc(`rooms/${roomId}/presence/${uid}`).get();
          if (presSnap.exists && presSnap.data().lastActiveAt) {
            const lastActive = presSnap.data().lastActiveAt.toMillis();
            if (now - lastActive < 30_000) {
              console.log(`Oyuncu ${uid} tekrar bağlandı, koltuk bota devredilmekten çıkarılıyor.`);
              continue; // tekrar aktif, bot seats'ten çıkar
            }
          }
          activeSeats.push(uid);
        }
        botControlledSeats = activeSeats;
      }

      if (pub.gameType === "batak") {
        const hands = {};
        for (const uid of playerOrder) hands[uid] = deck.splice(0, 13);
        
        const nextDealerIndex = (playerOrder.indexOf(pub.dealerId) + 1) % playerOrder.length;
        const nextDealerId = playerOrder[nextDealerIndex];
        const firstBidderIndex = (nextDealerIndex + 1) % playerOrder.length;

        for (const uid of playerOrder) {
          tx.set(db.doc(`rooms/${roomId}/hands/${uid}`), {cards: hands[uid]});
        }
        tx.update(publicRef, {
          phase: "bidding",
          dealerId: nextDealerId,
          bids: {},
          passedPlayers: [],
          highestBidderId: null,
          highestBid: 0,
          currentTurnPlayerId: playerOrder[firstBidderIndex],
          trumpSuit: null,
          trumpBroken: false,
          declarerId: null,
          currentTrick: [],
          trickLeaderId: null,
          tricksWon: Object.fromEntries(playerOrder.map((id) => [id, 0])),
          handCounts: Object.fromEntries(playerOrder.map((id) => [id, 13])),
          status: "playing",
          currentRound: nextRound,
          roundReady: Object.fromEntries(playerOrder.map((id) => [id, false])),
          botControlledSeats,
        });
      } else {
        const hands = {};
        for (const uid of playerOrder) hands[uid] = deck.splice(0, 4);
        const tableCards = deck.splice(0, 4);

        for (const uid of playerOrder) {
          tx.set(db.doc(`rooms/${roomId}/hands/${uid}`), {cards: hands[uid]});
        }
        tx.update(publicRef, {
          tableCards,
          currentTurnPlayerId: playerOrder[0],
          handCounts: Object.fromEntries(playerOrder.map((id) => [id, 4])),
          pistiCounts: Object.fromEntries(playerOrder.map((id) => [id, 0])),
          collectedCardCounts: Object.fromEntries(playerOrder.map((id) => [id, 0])),
          currentScores: Object.fromEntries(playerOrder.map((id) => [id, 0])),
          lastCollectorId: null,
          deckCount: deck.length,
          status: "playing",
          currentRound: nextRound,
          roundReady: Object.fromEntries(playerOrder.map((id) => [id, false])),
          botControlledSeats,
        });
        tx.set(privateRef, {
          deck,
          collectedCards: Object.fromEntries(playerOrder.map((id) => [id, []])),
        });
        tx.update(db.doc(`rooms/${roomId}`), {
          currentRound: nextRound,
        });
      }
    } else {
      tx.update(publicRef, {roundReady});
    }

    tx.update(moveRef, {status: "applied"});
  });
}

exports.onRoomStatusChange = onDocumentUpdated("rooms/{roomId}", async (event) => {
  const before = event.data.before.data();
  const after = event.data.after.data();
  const roomId = event.params.roomId;

  if (before.status === after.status) return;

  // Oyun tamamlandı veya terk edildi → 30 saniye bekle, sonra odayı sil
  if (after.status === "finished" || after.status === "abandoned") {
    await new Promise((r) => setTimeout(r, 30_000));
    await deleteRoom(roomId);
    return;
  }

  // Oyun başladı → oyunu başlat
  if (after.status !== "playing") return;

  const publicRef = db.doc(`rooms/${roomId}/gameState/public`);
  const publicSnap = await publicRef.get();
  if (publicSnap.exists) return;

  const playerOrder = Object.keys(after.players || {});
  const gameType = after.gameType || "pisti";
  const totalRounds = after.totalRounds || 1;

  if (gameType === "batak") {
    if (playerOrder.length < 4) return;
    await initBatakGame(roomId, playerOrder, totalRounds);
  } else {
    if (playerOrder.length < 2) return;
    await initPistiGame(roomId, playerOrder, totalRounds);
  }
});

exports.onMoveCreated = onDocumentCreated("rooms/{roomId}/moves/{moveId}", async (event) => {
  const roomId = event.params.roomId;
  const moveData = event.data.data();
  const playerId = moveData.playerId;
  const moveRef = event.data.ref;

  if (moveData.type === "roundReady") {
    await handleRoundReadyMove(roomId, playerId, moveRef);
    return;
  }

  const publicSnap = await db.doc(`rooms/${roomId}/gameState/public`).get();
  const gameType = publicSnap.exists ? (publicSnap.data().gameType || "pisti") : "pisti";

  if (gameType === "batak") {
    await handleBatakMove(roomId, playerId, moveData, moveRef);
  } else {
    await handlePistiMove(roomId, playerId, moveData.card, moveRef);
  }
});

// ============ BOT DEVRALMA (BOT TAKEOVER) MANITIĞI ============

function pistiBotDecideMove(pub, hand) {
  if (!hand || hand.length === 0) return null;
  const tableCards = pub.tableCards || [];
  if (tableCards.length > 0) {
    const topCard = tableCards[tableCards.length - 1];
    const matchCard = hand.find((c) => c.rank === topCard.rank);
    if (matchCard) return matchCard;

    const jackCard = hand.find((c) => c.rank === "jack");
    if (jackCard) return jackCard;
  }
  return hand[Math.floor(Math.random() * hand.length)];
}

function batakBotDecideMove(pub, hand) {
  const phase = pub.phase || "bidding";

  if (phase === "bidding") {
    const currentBid = pub.highestBid || 0;
    const nextBid = Math.max(MIN_BID, currentBid + 1);
    let willBid = false;

    if (currentBid < 7) {
      willBid = Math.random() < 0.7;
    } else if (currentBid === 7) {
      willBid = Math.random() < 0.25;
    } else if (currentBid === 8) {
      willBid = Math.random() < 0.05;
    }

    if (willBid && nextBid <= 13) {
      return {type: "bid", bid: nextBid};
    }
    return {type: "pass"};
  }

  if (phase === "chooseTrump") {
    const counts = {spades: 0, hearts: 0, diamonds: 0, clubs: 0};
    (hand || []).forEach((c) => {
      if (counts[c.suit] !== undefined) counts[c.suit]++;
    });
    let bestSuit = "spades";
    let maxCount = -1;
    for (const suit of SUITS) {
      if (counts[suit] > maxCount) {
        maxCount = counts[suit];
        bestSuit = suit;
      }
    }
    return {type: "chooseTrump", suit: bestSuit};
  }

  if (phase === "playing") {
    if (!hand || hand.length === 0) return null;

    const currentTrick = pub.currentTrick || [];
    const trumpSuit = pub.trumpSuit;
    const trumpBroken = pub.trumpBroken || false;

    const ledSuit = currentTrick.length > 0 ? currentTrick[0].card.suit : null;
    const hasLedSuit = ledSuit ? hand.some((c) => c.suit === ledSuit) : false;
    const isOpening = currentTrick.length === 0;

    let validCards = [...hand];

    if (hasLedSuit) {
      validCards = validCards.filter((c) => c.suit === ledSuit);

      const trumpInTrick = currentTrick.some((tc) => tc.card.suit === trumpSuit);
      if (!trumpInTrick && ledSuit) {
        let highestLedVal = -1;
        currentTrick.forEach((tc) => {
          if (tc.card.suit === ledSuit && RANK_VALUE[tc.card.rank] > highestLedVal) {
            highestLedVal = RANK_VALUE[tc.card.rank];
          }
        });
        if (highestLedVal >= 0) {
          const higher = validCards.filter((c) => RANK_VALUE[c.rank] > highestLedVal);
          if (higher.length > 0) validCards = higher;
        }
      }
    } else if (isOpening && !trumpBroken && trumpSuit) {
      const nonTrump = validCards.filter((c) => c.suit !== trumpSuit);
      if (nonTrump.length > 0) validCards = nonTrump;
    }

    const chosen = validCards.length > 0
      ? validCards[Math.floor(Math.random() * validCards.length)]
      : hand[Math.floor(Math.random() * hand.length)];

    return {type: "playCard", card: chosen};
  }

  return null;
}

async function triggerBotActionsIfNeeded(roomId) {
  const publicRef = db.doc(`rooms/${roomId}/gameState/public`);
  const publicSnap = await publicRef.get();
  if (!publicSnap.exists) return;
  const pub = publicSnap.data();
  const roomSnap = await db.doc(`rooms/${roomId}`).get();
  const roomData = roomSnap.exists ? roomSnap.data() : {};
  const playerOrder = pub.playerOrder || Object.keys(roomData.players || {});
  const botControlledSeats = Array.from(new Set([
    ...(pub.botControlledSeats || []),
    ...(roomData.botControlledSeats || []),
  ]));

  if (botControlledSeats.length === 0) return;

  // Odadaki tüm oyuncular çıktı/bot devrinde ise odayı tamamen sil
  if (playerOrder.length > 0 && botControlledSeats.length >= playerOrder.length) {
    console.log(`Odadaki tüm oyuncular çıktı/bot devrinde (${roomId}). Oda siliniyor.`);
    await deleteRoom(roomId);
    return;
  }

  // Tur sonu durumunda botlar için otomatik roundReady hamlesi
  if (pub.status === "roundFinished") {
    for (const botUid of botControlledSeats) {
      if (!pub.roundReady || !pub.roundReady[botUid]) {
        const moveRef = db.collection(`rooms/${roomId}/moves`).doc();
        await moveRef.set({
          type: "roundReady",
          playerId: botUid,
          createdAt: new Date().toISOString(),
        });
      }
    }
    return;
  }

  if (pub.status !== "playing") return;

  let currentTurn = pub.currentTurnPlayerId;
  if (!currentTurn) return;

  // İnaktiflik kontrolü (60 saniye boyunca varlık sinyali gelmemişse bot devralır)
  if (!botControlledSeats.includes(currentTurn)) {
    const presSnap = await db.doc(`rooms/${roomId}/presence/${currentTurn}`).get();
    let isInactive = false;
    let is60sAbandoned = false;

    if (presSnap.exists && presSnap.data().lastActiveAt) {
      const lastActive = presSnap.data().lastActiveAt.toMillis();
      const diff = Date.now() - lastActive;
      if (diff > 35_000) {
        isInactive = true;
      }
      if (diff > 60_000) {
        is60sAbandoned = true;
      }
    } else {
      // Presence dökümanı henüz yoksa oyuncuyu aktif varsay (bot devralmasın)
      isInactive = false;
    }

    if (isInactive) {
      console.log(`Oyuncu ${currentTurn} 35s boyunca inaktif/uygulamadan çıkmış, bot devralıyor.`);
      botControlledSeats.push(currentTurn);
      const abandonedUsersCounted = pub.abandonedUsersCounted || [];

      if (is60sAbandoned && !abandonedUsersCounted.includes(currentTurn)) {
        abandonedUsersCounted.push(currentTurn);
        try {
          await db.doc(`users/${currentTurn}`).set({
            stats: {
              abandonedGamesCount: FieldValue.increment(1),
            },
          }, {merge: true});
        } catch (e) {
          console.error("User abandoned stats güncellenemedi:", e);
        }
      }

      await publicRef.update({
        botControlledSeats: Array.from(new Set(botControlledSeats)),
        abandonedUsersCounted: Array.from(new Set(abandonedUsersCounted)),
      });
      await db.doc(`rooms/${roomId}`).update({
        botControlledSeats: Array.from(new Set(botControlledSeats)),
        abandonedUsersCounted: Array.from(new Set(abandonedUsersCounted)),
      });
    } else {
      // Sıradaki oyuncu aktif ve bot kontrolünde değil, sırasını bekler
      return;
    }
  }

  // Bot hamlesi öncesi 700ms gerçekçi gecikme
  await new Promise((r) => setTimeout(r, 700));

  const handSnap = await db.doc(`rooms/${roomId}/hands/${currentTurn}`).get();
  const hand = handSnap.exists ? (handSnap.data().cards || []) : [];

  if (pub.gameType === "batak") {
    const botMove = batakBotDecideMove(pub, hand);
    if (botMove) {
      botMove.playerId = currentTurn;
      botMove.createdAt = new Date().toISOString();
      const moveRef = db.collection(`rooms/${roomId}/moves`).doc();
      await moveRef.set(botMove);
    }
  } else {
    const card = pistiBotDecideMove(pub, hand);
    if (card) {
      const moveRef = db.collection(`rooms/${roomId}/moves`).doc();
      await moveRef.set({
        type: "playCard",
        playerId: currentTurn,
        card: card,
        createdAt: new Date().toISOString(),
      });
    }
  }
}

exports.onPublicGameStateChange = onDocumentUpdated("rooms/{roomId}/gameState/public", async (event) => {
  const roomId = event.params.roomId;
  await triggerBotActionsIfNeeded(roomId);
});

exports.onRoomUpdated = onDocumentUpdated("rooms/{roomId}", async (event) => {
  const roomId = event.params.roomId;
  await triggerBotActionsIfNeeded(roomId);
});

exports.onRoomDeleted = onDocumentDeleted("rooms/{roomId}", async (event) => {
  const roomId = event.params.roomId;
  console.log(`Oda dokümanı silindi, alt koleksiyonlar temizleniyor: ${roomId}`);
  await deleteCollection(db.collection(`rooms/${roomId}/gameState`));
  await deleteCollection(db.collection(`rooms/${roomId}/hands`));
  await deleteCollection(db.collection(`rooms/${roomId}/moves`));
  await deleteCollection(db.collection(`rooms/${roomId}/presence`));
});