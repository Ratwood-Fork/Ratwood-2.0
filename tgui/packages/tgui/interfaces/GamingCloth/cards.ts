/**
 * Reading card names. The server sends the deck's own strings, such as
 * "Ace of Spades" or "10 of Hearts". The 52 standard names get a drawn
 * face and anything else, tarot included, is shown as its name.
 */
import type { HandCard } from './types';

export enum Suit {
  Hearts = 'Hearts',
  Diamonds = 'Diamonds',
  Clubs = 'Clubs',
  Spades = 'Spades',
}

export type ParsedCard = {
  // A, 2 to 10, J, Q or K
  rank: string;
  // 1 for an ace to 13 for a king
  value: number;
  suit: Suit;
  glyph: string;
  red: boolean;
};

export enum SortMode {
  Dealt = 'dealt',
  Suit = 'suit',
  Rank = 'rank',
}

// The variation selector keeps the suit glyphs as text, never as emoji
const TEXT_STYLE = '︎';

const SUIT_GLYPHS: Record<Suit, string> = {
  [Suit.Hearts]: '♥' + TEXT_STYLE,
  [Suit.Diamonds]: '♦' + TEXT_STYLE,
  [Suit.Clubs]: '♣' + TEXT_STYLE,
  [Suit.Spades]: '♠' + TEXT_STYLE,
};

const SUIT_ORDER: Suit[] = [
  Suit.Spades,
  Suit.Hearts,
  Suit.Clubs,
  Suit.Diamonds,
];

const RANKS: Record<string, [string, number]> = {
  Ace: ['A', 1],
  Jack: ['J', 11],
  Queen: ['Q', 12],
  King: ['K', 13],
};

const NAME_PATTERN = /^(Ace|Jack|Queen|King|[2-9]|10) of (\w+)$/;

/** The rank and suit of a standard card name, or null for anything else */
export function parseCard(name: string | null | undefined): ParsedCard | null {
  if (!name) {
    return null;
  }
  const match = NAME_PATTERN.exec(name);
  if (!match) {
    return null;
  }
  const suit = match[2] as Suit;
  if (!SUIT_GLYPHS[suit]) {
    return null;
  }
  const [rank, value] = RANKS[match[1]] ?? [match[1], parseInt(match[1], 10)];
  return {
    rank,
    value,
    suit,
    glyph: SUIT_GLYPHS[suit],
    red: suit === Suit.Hearts || suit === Suit.Diamonds,
  };
}

/** Orders the hand for display only, keeping the dealt order for ties */
export function sortHand(hand: HandCard[], mode: SortMode): HandCard[] {
  if (mode === SortMode.Dealt) {
    return hand;
  }
  const keyed = hand.map((card, index) => ({
    card,
    index,
    parsed: parseCard(card.name),
  }));
  keyed.sort((a, b) => {
    // Cards with no rank or suit go after the standard ones, by name
    if (!a.parsed || !b.parsed) {
      if (a.parsed) {
        return -1;
      }
      if (b.parsed) {
        return 1;
      }
      return a.card.name.localeCompare(b.card.name) || a.index - b.index;
    }
    const bySuit =
      SUIT_ORDER.indexOf(a.parsed.suit) - SUIT_ORDER.indexOf(b.parsed.suit);
    const byRank = a.parsed.value - b.parsed.value;
    const first = mode === SortMode.Suit ? bySuit : byRank;
    const second = mode === SortMode.Suit ? byRank : bySuit;
    return first || second || a.index - b.index;
  });
  return keyed.map((entry) => entry.card);
}

/** The class suffix that tints a card back for a deck style */
export function backStyle(style: string | null | undefined): string {
  if (style === 'tarot') {
    return 'tarot';
  }
  if (style === 'syndicate') {
    return 'syndicate';
  }
  return 'plain';
}
