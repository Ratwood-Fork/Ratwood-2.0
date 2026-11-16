import type { CSSProperties } from 'react';
import { Button } from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { PlayingCard } from './PlayingCard';
import type { SeatData } from './types';
import { Side } from './view';

const SIDE_NAMES: Record<Side, string> = {
  [Side.Bottom]: 'bottom',
  [Side.Left]: 'left',
  [Side.Top]: 'top',
  [Side.Right]: 'right',
};

/** Room for a seat's row of small cards in pixels, past which they overlap more */
const ROW_ROOM = 260;
const COLUMN_ROOM = 230;
const MINI_STEP_MAX = 18;

type LabelProps = {
  seat: number;
  data: SeatData;
  side: Side;
  isYou: boolean;
  deckStyle: string;
};

/**
 * A seat's label outside the felt, on the side where that seat sits for
 * this viewer. Other seats show a card back per card in hand, or the faces
 * while the hand is shown. The viewer's own hand is in the tray instead.
 */
export function SeatLabel(props: LabelProps) {
  const { seat, data, side, isYou, deckStyle } = props;
  const isEmpty = !data?.name;
  const isColumn = side === Side.Left || side === Side.Right;
  const shown = data?.showing ?? null;
  const count = shown ? shown.length : data?.cards || 0;
  const step = Math.min(
    MINI_STEP_MAX,
    (isColumn ? COLUMN_ROOM : ROW_ROOM) / Math.max(1, count),
  );

  return (
    <div
      className={classes([
        'GamingCloth__seat',
        `GamingCloth__seat--${SIDE_NAMES[side]}`,
        isEmpty && 'GamingCloth__seat--empty',
      ])}
      data-seat={seat}
    >
      <div className="GamingCloth__seatText">
        <div className="GamingCloth__seatName">
          {isEmpty ? `Seat ${seat} empty` : data.name}
        </div>
        {!isEmpty && (
          <div className="GamingCloth__seatInfo">
            {isYou && <span className="GamingCloth__tag">you</span>}
            <span>
              {data.cards} {data.cards === 1 ? 'card' : 'cards'}
            </span>
            {!!data.away && (
              <span className="GamingCloth__tag GamingCloth__tag--away">
                away
              </span>
            )}
            {!!shown && <span className="GamingCloth__tag">showing</span>}
          </div>
        )}
      </div>
      {!isEmpty && !isYou && count > 0 && (
        <div
          className={classes([
            'GamingCloth__minis',
            isColumn && 'GamingCloth__minis--column',
          ])}
          style={{ '--mini-step': `${step}px` } as CSSProperties}
        >
          {shown
            ? shown.map((name) => (
                <PlayingCard
                  key={name}
                  name={name}
                  deckStyle={deckStyle}
                  size="mini"
                />
              ))
            : Array.from({ length: count }, (_, index) => (
                <PlayingCard
                  key={index}
                  name={null}
                  deckStyle={deckStyle}
                  size="mini"
                />
              ))}
        </div>
      )}
    </div>
  );
}

type ListProps = {
  seats: SeatData[];
  you: number;
  isInteractive: boolean;
};

/** The side panel's seat list with Sit, Stand and Unseat */
export function SeatList(props: ListProps) {
  const { seats, you, isInteractive } = props;
  return (
    <div className="GamingCloth__seatList">
      {seats.map((data, index) => {
        const seat = index + 1;
        const isEmpty = !data?.name;
        const canSit = isEmpty && isInteractive && !you;
        const canUnseat =
          !isEmpty && !!data.away && seat !== you && isInteractive;
        return (
          <div key={seat} className="GamingCloth__seatRow">
            <span className="GamingCloth__seatNumber">{seat}</span>
            <span
              className={classes([
                'GamingCloth__seatRowName',
                isEmpty && 'GamingCloth__seatRowName--empty',
              ])}
            >
              {isEmpty ? 'Empty' : data.name}
            </span>
            {canSit && <Button compact>Sit</Button>}
            {seat === you && <Button compact>Stand</Button>}
            {canUnseat && <Button compact>Unseat</Button>}
          </div>
        );
      })}
    </div>
  );
}
