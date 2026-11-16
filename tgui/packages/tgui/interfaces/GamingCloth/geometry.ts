/**
 * Layout maths with no turning of its own: the hand's fan and where a
 * selected card is nudged so its enlarged picture stays on the felt.
 */
import { CARD_HEIGHT, CARD_WIDTH, FELT_SIZE, type Point } from './types';
import { rotate, toScreen } from './view';

/** How much a selected card grows where it lies */
export const LIFT_SCALE = 1.6;
/** How far a selected felt card rises up the screen, in felt units */
export const LIFT_RISE = 16;
/**
 * How far a selected hand card rises out of the fan, in card widths. At
 * LIFT_SCALE it already reaches over the strip above the tray, so it rises
 * only a little
 */
export const HAND_LIFT_RISE = 0.25;

/** Gap between hand cards, in card widths, up to FAN_LOOSE_MAX cards */
const FAN_GAP = 0.62;
/** Past this many cards the fan keeps its width and the gap tightens */
const FAN_LOOSE_MAX = 10;
/** Lean of the outermost card in degrees, and the drop of the ends in card widths */
const FAN_LEAN = 10;
const FAN_DROP = 0.18;

export type FanSpot = {
  // Centre offset from the middle of the tray, in the unit of width
  x: number;
  // Downward drop of the card, in the unit of width
  y: number;
  // Lean in degrees, clockwise
  angle: number;
};

/**
 * Places count cards in a fan across a tray width wide, for cards
 * cardWidth wide in the same unit. Spacing is even, tightens past ten
 * cards and never lets the outer cards leave the tray. The ends lean
 * outward and drop a little, so the fan reads as an arc.
 */
export function handLayout(
  count: number,
  width: number,
  cardWidth: number,
): FanSpot[] {
  if (count <= 0) {
    return [];
  }
  const loose = cardWidth * FAN_GAP;
  const tightened =
    count > FAN_LOOSE_MAX ? (loose * (FAN_LOOSE_MAX - 1)) / (count - 1) : loose;
  const fits = count > 1 ? Math.max(0, width - cardWidth) / (count - 1) : 0;
  const gap = count > 1 ? Math.min(tightened, fits) : 0;
  const middle = (count - 1) / 2;
  const spread = Math.min(1, count / FAN_LOOSE_MAX);
  const spots: FanSpot[] = [];
  for (let i = 0; i < count; i++) {
    const along = middle ? (i - middle) / middle : 0;
    spots.push({
      x: (i - middle) * gap,
      y: along * along * FAN_DROP * cardWidth * spread,
      angle: along * FAN_LEAN * spread,
    });
  }
  return spots;
}

/**
 * The selected card's offset, in felt units in its lift wrapper's own
 * frame, so that at LIFT_SCALE it rises a little and stays inside the
 * felt box. The lift wrapper sits inside the layer, turned by angle, and
 * the turn wrapper, turned by rot minus angle, so its frame is turned by
 * rot from the screen.
 */
export function liftOffset(
  x: number,
  y: number,
  rot: number,
  angle: number,
): Point {
  const sideways = Math.abs(rot % 180) === 90;
  const halfWidth = ((sideways ? CARD_HEIGHT : CARD_WIDTH) / 2) * LIFT_SCALE;
  const halfHeight = ((sideways ? CARD_WIDTH : CARD_HEIGHT) / 2) * LIFT_SCALE;
  const from = toScreen(x, y, angle);
  const toX = clamp(from.x, halfWidth, FELT_SIZE - halfWidth);
  const toY = clamp(from.y - LIFT_RISE, halfHeight, FELT_SIZE - halfHeight);
  return rotate(toX - from.x, toY - from.y, -rot);
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(high, Math.max(low, value));
}
