/**
 * What moves and how, as pure functions, so the hooks only find elements
 * and hand these keyframes to the browser. The numbers come from the
 * examine gallery's card deal, hop and tilt, which were tuned by eye there.
 * Every motion is a transform or an opacity played by the browser, and
 * nothing runs once it has landed.
 */
import {
  DECK_SPOT,
  type FeltCard,
  type HandCard,
  type Point,
  SEAT_ANCHORS,
  type TableEvent,
} from './types';
import { rotate } from './view';

/** The deal's flight, the gallery's picture deal at 0.52 s */
export const DEAL_MS = 520;
/** Gap between cards dealt together, the gallery's thumbnail stagger */
export const DEAL_STAGGER_MS = 90;
/** Share of the flight at which the card touches down, the squash keyframe */
export const DEAL_TOUCHDOWN = 0.58;
/** A card fading into or out of the hand, and every arrival under reduced motion */
export const FADE_MS = 300;
/** The deck's hop and wiggle on a shuffle, the gallery's hop on becoming selected */
export const HOP_MS = 500;
/** A card turning over shows its new side turning in from edge on */
export const FLIP_MS = 200;
/** The slide of a moved card, the anchor's transition in GamingCloth.scss */
export const SLIDE_MS = 220;

/** The tilt's lean at the card's edge in degrees, the gallery's 7 each way */
export const TILT_DEGREES = 7;
/** A pointer move smaller than this share of the card picks no new lean */
export const TILT_DEAD_ZONE = 1 / 6;
/** Once the pointer rests this long the lean goes exactly where it points */
export const TILT_REST_MS = 100;

/** Events newer than the mark. A null mark is the first payload, which animates nothing */
export function freshEvents(
  events: TableEvent[] | undefined,
  mark: number | null,
): TableEvent[] {
  if (mark === null || !events?.length) {
    return [];
  }
  return events
    .filter((event) => event.seq > mark)
    .sort((a, b) => a.seq - b.seq);
}

/** The highest seq seen so far, 0 once a payload has come with no events */
export function highestSeq(
  events: TableEvent[] | undefined,
  mark: number | null,
): number {
  let highest = mark ?? 0;
  for (const event of events || []) {
    highest = Math.max(highest, event.seq);
  }
  return highest;
}

/** Where a card named by an event's from flies in from, in table coordinates */
export function fromPoint(from: string | undefined): Point | null {
  if (from === 'deck') {
    return DECK_SPOT;
  }
  const seat = /^seat([1-4])$/.exec(from || '');
  if (!seat) {
    return null;
  }
  return SEAT_ANCHORS[Number(seat[1])];
}

export type FeltArrival = {
  h: number;
  // Table offset from the card's spot to where it flies in from
  offset: Point;
};

/**
 * Felt cards that fly in: new on the felt, named by a fresh event that has
 * a from, and not moved by the viewer, who already saw their own move.
 */
export function feltArrivals(
  fresh: TableEvent[],
  before: Set<number>,
  felt: FeltCard[],
  you: number,
): FeltArrival[] {
  const arrivals: FeltArrival[] = [];
  for (const event of fresh) {
    const start = fromPoint(event.from);
    if (!start || event.h === undefined || event.seat === you) {
      continue;
    }
    if (before.has(event.h) || arrivals.some((a) => a.h === event.h)) {
      continue;
    }
    const card = felt.find((c) => c.h === event.h);
    if (!card) {
      continue;
    }
    arrivals.push({
      h: card.h,
      offset: { x: start.x - card.x, y: start.y - card.y },
    });
  }
  return arrivals;
}

export type HandArrival = {
  h: number;
  // Thrown from the deck when another player dealt it, else it fades in
  isDealt: boolean;
};

/** Cards new in the viewer's hand, in the order they are held */
export function handArrivals(
  fresh: TableEvent[],
  before: Set<number>,
  hand: HandCard[],
  you: number,
): HandArrival[] {
  const isDealt = fresh.some(
    (event) => event.kind === 'deal' && event.seat !== you,
  );
  return hand
    .filter((card) => !before.has(card.h))
    .map((card) => ({ h: card.h, isDealt }));
}

/** Felt cards a fresh event turned over, still on the felt and now showing the other side */
export function flippedCards(
  fresh: TableEvent[],
  before: Map<number, FeltCard>,
  felt: FeltCard[],
): number[] {
  const flipped: number[] = [];
  for (const event of fresh) {
    if (event.kind !== 'flip' || event.h === undefined) {
      continue;
    }
    const was = before.get(event.h);
    const card = felt.find((c) => c.h === event.h);
    if (!was || !card || !was.name === !card.name) {
      continue;
    }
    if (!flipped.includes(card.h)) {
      flipped.push(card.h);
    }
  }
  return flipped;
}

/** Felt cards a fresh event moved to a new spot, which slide there by themselves */
export function movedCards(
  fresh: TableEvent[],
  before: Map<number, FeltCard>,
  felt: FeltCard[],
): number[] {
  const moved: number[] = [];
  for (const event of fresh) {
    if (event.kind !== 'move' || event.h === undefined) {
      continue;
    }
    const was = before.get(event.h);
    const card = felt.find((c) => c.h === event.h);
    if (!was || !card || (was.x === card.x && was.y === card.y)) {
      continue;
    }
    if (!moved.includes(card.h)) {
      moved.push(card.h);
    }
  }
  return moved;
}

/** Whether a fresh event shuffled the deck, which collecting does too */
export function isShuffled(fresh: TableEvent[]): boolean {
  return fresh.some(
    (event) => event.kind === 'shuffle' || event.kind === 'collect',
  );
}

/** Which way a card thrown along a screen vector leans as it flies */
export function dealDirection(screenDx: number): number {
  return screenDx < 0 ? -1 : 1;
}

const px = (value: number) => `${round(value)}px`;

/**
 * The gallery's picture deal from a start offset: thrown in turning, a
 * squash 2 px low and 4 px on past its spot as it lands, then a 1 px spring
 * back, never outside its own box once down. The start is already written
 * in the frame of the element animated. Landing offsets are in screen
 * pixels, turned into that frame by frameAngle, the frame's own turn from
 * the screen.
 */
export function dealKeyframes(
  start: string,
  direction: number,
  frameAngle: number,
): Keyframe[] {
  const squash = rotate(-4 * direction, 2, -frameAngle);
  const spring = rotate(0, -1, -frameAngle);
  return [
    {
      offset: 0,
      opacity: 0,
      transform: `${start} rotate(${18 * direction}deg) scale(0.7)`,
      easing: 'ease-out',
    },
    { offset: 0.06, opacity: 1, easing: 'ease-out' },
    {
      offset: DEAL_TOUCHDOWN,
      transform: `translate(${px(squash.x)}, ${px(squash.y)}) rotate(${-0.75 * direction}deg) scale(0.985)`,
      easing: 'ease-out',
    },
    {
      offset: 0.78,
      transform: `translate(${px(spring.x)}, ${px(spring.y)}) rotate(0deg) scale(1.005)`,
      easing: 'ease-out',
    },
    {
      offset: 1,
      opacity: 1,
      transform: 'translate(0px, 0px) rotate(0deg) scale(1)',
    },
  ];
}

/** The gallery's hop with a wiggle, played by the deck on a shuffle, rising up the screen */
export function hopKeyframes(frameAngle: number): Keyframe[] {
  const steps: [number, number, number, number][] = [
    [0, 0, 1, 0],
    [0.3, -14, 1.1, -6],
    [0.5, -12, 1.1, 5],
    [0.7, -6, 1.05, -3],
    [0.85, -2, 1, 1.5],
    [1, 0, 1, 0],
  ];
  return steps.map(([offset, rise, scale, turn]) => {
    const up = rotate(0, rise, -frameAngle);
    return {
      offset,
      transform: `translate(${px(up.x)}, ${px(up.y)}) rotate(${turn}deg) scale(${scale})`,
      easing: 'ease-out',
    };
  });
}

export const FADE_IN_KEYFRAMES: Keyframe[] = [{ opacity: 0 }, { opacity: 1 }];

export const FLIP_KEYFRAMES: Keyframe[] = [
  { transform: 'rotateY(90deg)' },
  { transform: 'rotateY(0deg)' },
];

/**
 * Where the lifted card leans, as the pointer's spot on the card from -0.5
 * at its left or top edge to 0.5 at its right or bottom. A move inside the
 * dead zone keeps the last target, so a small wobble of the hand does not
 * restart the ease, unless exact is set once the pointer rests. rot is the
 * card's own quarter turns, as its face is turned by that from the screen.
 */
export function aimTilt(
  pointer: Point | null,
  box: { left: number; top: number; width: number; height: number },
  rot: number,
  target: Point,
  exact: boolean,
): Point {
  if (!pointer || box.width <= 0 || box.height <= 0) {
    return { x: 0, y: 0 };
  }
  const sideways = Math.abs(rot % 180) === 90;
  const local = rotate(
    pointer.x - (box.left + box.width / 2),
    pointer.y - (box.top + box.height / 2),
    -rot,
  );
  const x = clamp(local.x / (sideways ? box.height : box.width), -0.5, 0.5);
  const y = clamp(local.y / (sideways ? box.width : box.height), -0.5, 0.5);
  if (
    exact ||
    Math.abs(x - target.x) >= TILT_DEAD_ZONE ||
    Math.abs(y - target.y) >= TILT_DEAD_ZONE
  ) {
    return { x, y };
  }
  return target;
}

/**
 * The lean as a CSS rotate value. The gallery turns by rotateY then rotateX
 * on an element of its own. Here the face already holds the flip in its
 * transform, so the same lean is one turn about an axis in the card's plane
 * through the individual rotate property, which adds to the transform.
 */
export function tiltRotate(target: Point): string {
  const reach = Math.hypot(target.x, target.y);
  if (reach === 0) {
    return 'none';
  }
  const degrees = TILT_DEGREES * 2 * reach;
  return `${round(-target.y)} ${round(target.x)} 0 ${round(degrees)}deg`;
}

/**
 * A card face's own motion, a class in GamingCloth.scss: the gallery's leap
 * and wiggle while hovered in the hand, its drop on leaving, and its hop on
 * becoming selected, from the leap's pose when the card was up.
 */
export type FaceMotion = 'leap' | 'drop' | 'picked' | 'leapPicked';

export type FaceChange = 'enter' | 'leave' | 'select' | 'deselect' | 'end';

/** The face's motion after a change. The leap holds until the pointer leaves, the rest clear once played */
export function nextFaceMotion(
  current: FaceMotion | null,
  change: FaceChange,
  isSelected: boolean,
  isHovered: boolean,
): FaceMotion | null {
  switch (change) {
    case 'enter':
      return isSelected ? current : 'leap';
    case 'leave':
      return current === 'leap' ? 'drop' : current;
    case 'select':
      return current === 'leap' ? 'leapPicked' : 'picked';
    case 'deselect':
      return isHovered ? 'leap' : null;
    case 'end':
      return current === 'leap' ? current : null;
  }
}

/** Read at the moment of each motion, so a change in the system setting takes effect at once */
export function prefersReducedMotion(): boolean {
  return (
    typeof window !== 'undefined' &&
    !!window.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  );
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(high, Math.max(low, value));
}

function round(value: number): number {
  return Math.round(value * 1000) / 1000 || 0;
}
