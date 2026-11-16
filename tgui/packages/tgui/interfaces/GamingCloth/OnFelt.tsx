import type { ReactElement } from 'react';
import { classes } from 'tgui-core/react';

import { LIFT_SCALE } from './geometry';
import type { Point } from './types';

type Props = {
  // Table coordinates of the thing's centre
  x: number;
  y: number;
  // The thing's own quarter turns in degrees, 0 for the deck, dice and pot
  rot: number;
  // The viewer's layer angle from viewAngle
  angle: number;
  // Paint order among the things on the felt
  depth: number;
  // Names the arrival wrapper for the motions of useEvents
  motion: string;
  // Set while the thing is selected, from liftOffset
  lift?: Point | null;
  // The face, the fifth element. It has the size and takes the pointer
  children: ReactElement;
};

/** Felt units to the felt box's container units, 1000 units across */
const units = (value: number) => `${value / 10}cqw`;

/**
 * One thing on the felt, as five nested elements with one job each, so no
 * two transforms overwrite each other. The anchor has no size and is placed
 * in table coordinates, so a move the server reports slides by itself. The
 * arrival wrapper carries the flight in, in table offsets. The turn wrapper
 * stands the thing upright for this viewer. The lift wrapper raises a
 * selected card. Only the face takes the pointer, so what the player sees
 * is what takes the click.
 */
export function OnFelt(props: Props) {
  const { x, y, rot, angle, depth, motion, lift, children } = props;
  return (
    <div
      className="GamingCloth__anchor"
      style={{
        transform: `translate(${units(x)}, ${units(y)})`,
        zIndex: depth,
      }}
    >
      <div className="GamingCloth__arrival" data-motion={motion}>
        <div
          className="GamingCloth__turn"
          style={{ transform: `rotate(${rot - angle}deg)` }}
        >
          <div
            className={classes([
              'GamingCloth__lift',
              !!lift && 'GamingCloth__lift--up',
            ])}
            style={
              lift
                ? {
                    transform: `translate(${units(lift.x)}, ${units(lift.y)}) scale(${LIFT_SCALE})`,
                  }
                : undefined
            }
          >
            {children}
          </div>
        </div>
      </div>
    </div>
  );
}
