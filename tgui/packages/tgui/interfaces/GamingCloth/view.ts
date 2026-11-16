/**
 * Every turn of the picture between table and screen lives here.
 *
 * The server keeps one table, seat 1 at the bottom. Each window rotates
 * the felt layer so its own seat comes to the bottom. Angles are CSS
 * degrees, so with y pointing down a positive angle turns clockwise.
 * Pointer maths works in fractions of the unturned felt box measured at
 * the event, since tgui can zoom the whole page and offsetX and offsetY
 * are in the turned layer's own space.
 */
import { FELT_SIZE, type Point } from './types';

/** The felt layer's rotation for a viewer in seat 1 to 4, and 0 for a watcher */
const VIEW_ANGLES = [0, 0, -90, 180, 90];

export type FeltBox = {
  left: number;
  top: number;
  width: number;
  height: number;
};

/** Sides of the felt as seen by the viewer */
export enum Side {
  Bottom = 0,
  Left = 1,
  Top = 2,
  Right = 3,
}

const HALF = FELT_SIZE / 2;

export function viewAngle(you: number): number {
  return VIEW_ANGLES[you] ?? 0;
}

/** Turns a vector by angle degrees the way CSS rotate() does */
export function rotate(dx: number, dy: number, angle: number): Point {
  const radians = (angle * Math.PI) / 180;
  const cos = Math.cos(radians);
  const sin = Math.sin(radians);
  return { x: dx * cos - dy * sin, y: dx * sin + dy * cos };
}

/** A table point to where it is drawn in the unturned felt box, in felt units */
export function toScreen(x: number, y: number, angle: number): Point {
  const turned = rotate(x - HALF, y - HALF, angle);
  return { x: turned.x + HALF, y: turned.y + HALF };
}

/** A pointer position to table coordinates */
export function toTable(
  clientX: number,
  clientY: number,
  feltBox: FeltBox,
  angle: number,
): Point {
  const screenX = ((clientX - feltBox.left) / feltBox.width) * FELT_SIZE;
  const screenY = ((clientY - feltBox.top) / feltBox.height) * FELT_SIZE;
  const turned = rotate(screenX - HALF, screenY - HALF, -angle);
  return { x: turned.x + HALF, y: turned.y + HALF };
}

/** A pointer movement in pixels to a table vector in felt units */
export function turnVector(
  dxPixels: number,
  dyPixels: number,
  feltBox: FeltBox,
  angle: number,
): Point {
  return rotate(
    (dxPixels / feltBox.width) * FELT_SIZE,
    (dyPixels / feltBox.height) * FELT_SIZE,
    -angle,
  );
}

/** Which side of the felt seat is drawn on, with a watcher seeing it as seat 1 does */
export function seatSide(seat: number, you: number): Side {
  const viewer = you || 1;
  return (seat - viewer + 4) % 4;
}
