import type { BooleanLike } from 'tgui-core/react';

/** What ui_static_data sends */
export type GamingClothStaticData = {
  // Ops messages a minute this client may send, 0 for no limit
  act_budget: number;
  // Ops messages the server has counted from this client in the current minute
  act_used: number;
};

export type SeatData = {
  // null means empty
  name: string | null;
  // Cards in hand
  cards: number;
  // Card names while the hand is shown to all, else null
  showing: string[] | null;
  // Occupant has no client or is not conscious, so Unseat is offered
  away: BooleanLike;
  chips: number;
};

export type DeckData = {
  present: BooleanLike;
  count: number;
  // The deck item's deckstyle
  style: string;
};

/**
 * A card on the felt, in paint order.
 * A face-down card's name arrives as null or with the key left out
 */
export type FeltCard = {
  h: number;
  x: number;
  y: number;
  rot: number;
  name: string | null;
};

export type HandCard = {
  h: number;
  name: string;
};

export type DieData = {
  id: number;
  sides: number;
  label: string;
  face: number;
  x: number;
  y: number;
  // The last throw, in table coordinates
  from_x: number;
  from_y: number;
  dx: number;
  dy: number;
  // Revision of the last throw, 0 if never thrown
  thrown: number;
};

export type TableEvent = {
  seq: number;
  kind: string;
  seat: number;
  text: string;
  // Set only for a card on the felt
  h?: number;
  // deck or seat1 to seat4, where an arriving card or bet flies in from
  from?: string;
};

/**
 * What ui_data sends, one payload per viewer.
 * Private to the viewer: you, ack, hand and peeks. An empty peeks arrives
 * as [] and TRUE and FALSE arrive as 1 and 0
 */
export type GamingClothData = {
  // Rises by one on every change
  revision: number;
  // Your seat 1 to 4, 0 while watching
  you: number;
  // The highest op number the server has handled from your seat, 0 while watching
  ack: number;
  // Always 4 entries
  seats: SeatData[];
  deck: DeckData;
  pot: number;
  felt: FeltCard[];
  // Your hand only, [] for watchers
  hand: HandCard[];
  // Handle to name, face-down felt cards you peeked at
  peeks: Record<string, string>;
  dice: DieData[];
  events: TableEvent[];
};

/**
 * Fixed spots and sizes, mirrored from code/__DEFINES/gaming_cloth.dm.
 * Felt coordinates are whole numbers 0 to 1000 on both axes, a thing's
 * centre, the same for every viewer. Bottom, left and so on mean seat 1's view
 */
export const FELT_SIZE = 1000;
export const EDGE_MARGIN = 60;
export const EVENTS_KEPT = 10;
export const DEAL_MAX = 13;
export const MAX_DICE = 10;
export const SEAT_COUNT = 4;

export const CARD_ZONE_DECK = 1;
export const CARD_ZONE_HAND = 2;
export const CARD_ZONE_FELT = 3;

export type Point = { x: number; y: number };

export const DECK_SPOT: Point = { x: 400, y: 500 };

/** Where Flip Top lands the nth card since the deck was last shuffled */
export const flipTopSpot = (n: number): Point => ({
  x: 540 + 70 * (n % 4),
  y: 500,
});

/** Seat anchors by seat number, 1 to 4 bottom, left, top, right, and 0 the centre */
export const SEAT_ANCHORS: Point[] = [
  { x: 500, y: 500 },
  { x: 500, y: 880 },
  { x: 120, y: 500 },
  { x: 500, y: 120 },
  { x: 880, y: 500 },
];

/** A leaving player's cards sit this far apart along their seat's edge */
export const SET_DOWN_GAP = 12;

export const DICE_ROW_START: Point = { x: 300, y: 700 };
export const DICE_ROW_GAP = 60;

export const POT_SPOT: Point = { x: 500, y: 360 };

/** Sizes in felt units, used by the window only */
export const CARD_WIDTH = 90;
export const CARD_HEIGHT = 126;
export const DIE_SIZE = 56;
