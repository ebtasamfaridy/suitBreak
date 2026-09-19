# SuitBreak — Game Rules

> Working title: **SuitBreak**
>
> A multiplayer card game where the goal is to empty your hand. The **last player still holding cards is the sole loser**.

---

## 1. Objective

The objective of SuitBreak is to **get rid of all cards in your hand**.

A player who successfully reaches **zero cards** has won their individual game and is **out of the game**.

The game continues with the remaining active players until only one player remains.

That final remaining player is the **sole loser**.

There are no points, rankings, or multiple losers in the first version of the game.

---

## 2. Players

The game supports **N players**.

For the initial version, the intended practical range is **2–4 players**.

The implementation should allow the player count to be configurable so the range can be expanded later without rewriting the core game rules.

---

## 3. Deck

The game uses one standard **52-card deck** containing:

- 4 suits: Spades, Hearts, Diamonds, Clubs
- 13 ranks in each suit

### Rank order

From lowest to highest:

```text
2 < 3 < 4 < 5 < 6 < 7 < 8 < 9 < 10 < J < Q < K < A
```

Rank determines the priority of a card when comparing cards on the table.

### Suit priority

Suits do **not** have a permanent priority over one another.

A card from another suit is considered a **trump/suit-break card** only because it is played when the player cannot follow the current suit.

When determining the highest card on the table, the **rank is what matters**.

Example:

```text
♥7
♥K
♠A
```

`♠A` is the highest card because Ace is higher than King and 7.

---

## 4. Initial Deal

All 52 cards are distributed among the players.

The distribution is done one card at a time around the table until all cards have been dealt.

Because the number of players may not divide 52 evenly, some players may have **one more card than others**, but the difference in hand size must never be more than one card.

Examples:

```text
4 players → 13 / 13 / 13 / 13
3 players → 18 / 17 / 17
```

The exact player order used for dealing must remain deterministic once the game starts.

---

## 5. First Leader

The player who receives the **Ace of Spades (A♠)** is the first leader.

That player starts the first round and may play any card from their hand.

The suit of the first card played becomes the **current suit** for that round.

---

# 6. Round Rules

Each round consists of players playing cards in a fixed clockwise/turn order among the players who are still active.

A round can end in **one of two ways**.

---

## 6.1 Case 1 — Suit Break

The current suit is determined by the first card played in the round.

Every following active player must follow that suit **if they have at least one card of that suit**.

If a player has **no card of the current suit**, they may play **any card of another suit**.

That action is a **suit break**.

### Important

The moment a suit break happens:

1. The round ends immediately.
2. No later player gets to play in that round.
3. The cards currently on the table are compared.
4. The player who played the **highest-ranked card** takes all cards on the table.
5. The player who caused the suit break becomes the **leader of the next round**, subject to being an active player.
6. The next leader may play **any card** from their hand.

### Example

Player order:

```text
A → B → C → D
```

Cards played:

```text
A → ♥7
B → ♥K
C → ♠3
```

C has no Hearts, so C breaks the suit.

The round ends immediately. D does not play.

The cards are:

```text
♥7, ♥K, ♠3
```

`♥K` is the highest-ranked card, so **B takes all three cards**.

However, **C becomes the next leader**, because C caused the suit break.

C may now play any card from their hand.

---

## 6.2 Case 2 — No Suit Break

If every active player is able to follow the current suit, then no suit break occurs.

Play continues through the complete active-player order.

The round ends when the **last active player has played**.

### At the end of the round

1. The player who played the **highest-ranked card** becomes the leader of the next round.
2. **All cards played in this round are moved to the discarded pile.**
3. No player receives those cards back into their hand.
4. The new leader may play any card from their hand.

### Example

Player order:

```text
A → B → C → D
```

Cards played:

```text
A → ♥7
B → ♥K
C → ♥3
D → ♥10
```

Everyone was able to follow Hearts, so the round reaches D.

`♥K` is the highest-ranked card.

Therefore:

```text
B → becomes next leader
♥7, ♥K, ♥3, ♥10 → discarded pile
```

Nobody collects these cards.

---

# 7. Winning a Round vs Winning the Game

The player who has the highest-ranked card in a round does **not automatically win the game**.

The only way to win the game is to **empty your hand**.

This distinction is fundamental to SuitBreak.

### Example

A player may win a suit-break round and collect several cards.

That player is therefore farther from emptying their hand, even though they won the card comparison for that round.

---

# 8. Reaching Zero Cards

A player's primary goal is to reach **zero cards**.

However, reaching zero does not necessarily end the current round immediately.

### Rule

If a player plays their final card and their hand becomes empty:

- The player has successfully finished.
- The player will **not receive any new cards** after reaching zero.
- The current round is still allowed to finish according to the normal rules.
- If a later active player is able to play and breaks the suit, that suit break can still resolve the round.
- After the current round is fully resolved, the player who reached zero is permanently **out of the game**.

### Example

```text
A has 1 card: ♥7
B has cards
C has cards
```

A plays `♥7` and now has zero cards.

A has finished, but the current round still resolves according to the rules.

A does not return to future turns.

---

# 9. A Player Who Finishes While Breaking the Suit

A player may use their final card to break the suit.

Example:

```text
A → ♥7
B → ♥K
C → ♠3   ← C's final card
```

C now has zero cards.

The suit break still causes the round to end immediately.

The highest-ranked card on the table determines who takes the cards.

C is considered **finished/out of the game** after the round resolves.

Because C is no longer active, C cannot be the leader of a future round.

The next eligible active player must therefore be selected according to the normal game flow.

---

# 10. Finished Players Are Removed From Turn Order

Once a player has finished with zero cards, they are no longer an active participant.

They are skipped when determining whose turn comes next.

Example:

```text
A → finished
B → active
C → active
D → active
```

The active turn order becomes:

```text
B → C → D → B → C → D → ...
```

A does not receive any further turns.

---

# 11. Last Remaining Player

The game continues until exactly **one active player remains**.

That player is the **sole loser**.

Example:

```text
A → 0 cards → finished
B → 0 cards → finished
C → 0 cards → finished
D → 6 cards  → remaining
```

Therefore:

```text
D = sole loser
```

The game ends immediately once this condition is reached.

---

# 12. Leader Rules Summary

There are two different ways a next leader is chosen.

| End condition | Cards on table | Who leads next? |
|---|---|---|
| Suit break | Highest-ranked player collects them | Player who caused the suit break |
| No suit break | Moved to discard pile | Player who played the highest-ranked card |

### Important distinction

The player who collects cards and the player who leads next **may be different people**.

Example:

```text
A → ♥7
B → ♥K
C → ♠3  ← suit break
```

Result:

```text
B → collects the cards
C → leads the next round
```

---

# 13. Current Suit

The first card played by the leader establishes the current suit.

For example:

```text
Leader plays ♦9
```

Then:

```text
Current suit = Diamonds
```

Every active player who has at least one Diamond must play a Diamond.

A player without a Diamond may play any other suit, which immediately causes a suit break.

After the round ends, the next leader chooses a new card and therefore establishes a new current suit.

---

# 14. Important Strategy

SuitBreak is intentionally built around a tension between **getting rid of cards** and **avoiding unwanted card collection**.

A player should consider:

- which card to play when leading a round;
- whether a low or high card should be exposed;
- when they are likely to be forced into a suit break;
- which player will become the next leader;
- whether a move is likely to help another player empty their hand;
- whether winning the current card comparison actually helps or hurts their objective.

The game is therefore not simply about having the highest cards.

The ultimate objective remains:

> **Empty your hand and avoid being the last player with cards.**

---

# 15. Complete Round Example

Consider four active players:

```text
A → B → C → D
```

### Round 1

```text
A → ♥7
B → ♥K
C → ♠3
```

C has no Hearts and breaks the suit.

Round ends immediately.

```text
Highest card = ♥K
B collects all cards
C becomes next leader
```

### Round 2

C starts because C caused the previous suit break:

```text
C → ♦9
D → ♦J
A → ♦4
B → ♦Q
```

Everyone could follow Diamonds.

The round reaches B, the last active player in the order.

Highest card is `♦Q`, so:

```text
B becomes next leader
All four cards → discarded pile
```

B now starts the next round with any card.

---

# 16. State Definitions for the Game Engine

The implementation should represent a player with at least these states:

```text
ACTIVE
FINISHED
LOSER
```

A round should track at least:

```text
leader
current_suit
cards_played
players_who_played
suit_break_player
round_end_reason
highest_card
highest_card_player
```

The game should track:

```text
players
active_players
discard_pile
table_cards
current_leader
current_player
game_state
```

---

# 17. Non-Rules / Implementation Notes

These are implementation decisions rather than gameplay rules:

- The game should work completely offline.
- Multiplayer will use a local LAN connection.
- One player acts as the host/authority.
- Other players join the host over the same local Wi-Fi/hotspot.
- The core game rules must work without networking so they can be tested locally with bots first.
- Networking should synchronize player actions and authoritative game state rather than independently running competing game logic on each client.

---

# 18. Rule Invariants

These conditions should always remain true during a valid game:

1. Exactly one deck of 52 cards exists for a game.
2. Every card is in exactly one place: a player's hand, the current table, or the discard pile.
3. A finished player has zero cards.
4. A finished player never receives another card.
5. A finished player never takes another turn.
6. A suit break immediately ends the current round.
7. A no-break round always continues until the last active player has played.
8. A suit-break round gives table cards to the highest-ranked card player.
9. A no-break round moves all table cards to the discard pile.
10. After a suit break, the breaker is the intended next leader if still active; otherwise the next eligible active player is selected.
11. After a no-break round, the highest-ranked card player is the next leader if still active; otherwise the next eligible active player is selected.
12. The game ends when exactly one active player remains.
13. That remaining player is the sole loser.

---

# 19. Open Questions for Future Versions

The core rules above are frozen for the first playable version.

Potential future design questions include:

- Whether to support more than four players.
- Whether to add scoring across multiple games.
- Whether to introduce special cards or additional card effects.
- Whether to add rematch/replay features.
- Whether to add AI difficulty levels.
- Whether to add a spectator mode.

These should not be added until the base game is fully playable and stable.
