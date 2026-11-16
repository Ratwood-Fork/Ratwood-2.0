import type { AnimationEvent, MouseEvent, Ref } from 'react';
import { classes } from 'tgui-core/react';

import { backStyle, parseCard } from './cards';

type Props = {
  // The name to draw, null to draw the back
  name: string | null;
  // The deck's style, which tints the back
  deckStyle: string;
  // Where the card is drawn: felt, hand or mini (a seat's row)
  size: 'felt' | 'hand' | 'mini';
  // The card's handle, for the harness and the input of the next stage
  handle?: number;
  // A motion class from GamingCloth.scss, such as the hop on being selected
  motion?: string | null;
  ref?: Ref<HTMLDivElement>;
  onClick?: (event: MouseEvent<HTMLDivElement>) => void;
  onAnimationEnd?: (event: AnimationEvent<HTMLDivElement>) => void;
};

/**
 * One card face or back, drawn in CSS. Its size comes from --card-w on the
 * size class, so every part of the face scales with it. A standard name
 * shows rank and suit in two opposite corners, so one of them shows
 * whichever way cards overlap. Any other name is printed as text.
 */
export function PlayingCard(props: Props) {
  const {
    name,
    deckStyle,
    size,
    handle,
    motion,
    ref,
    onClick,
    onAnimationEnd,
  } = props;
  const className = classes([
    'GamingCloth__card',
    `GamingCloth__card--${size}`,
    !name && `GamingCloth__back--${backStyle(deckStyle)}`,
    !!motion && `GamingCloth__motion--${motion}`,
  ]);
  return (
    <div
      ref={ref}
      className={className}
      data-h={handle}
      onClick={onClick}
      onAnimationEnd={onAnimationEnd}
    >
      {!!name && <CardFace name={name} isMini={size === 'mini'} />}
    </div>
  );
}

function CardFace(props: { name: string; isMini: boolean }) {
  const { name, isMini } = props;
  const parsed = parseCard(name);
  if (!parsed) {
    return <div className="GamingCloth__text">{name}</div>;
  }
  const colour = classes([
    'GamingCloth__face',
    parsed.red && 'GamingCloth__face--red',
  ]);
  const corner = (
    <>
      <span className="GamingCloth__rank">{parsed.rank}</span>
      <span className="GamingCloth__suit">{parsed.glyph}</span>
    </>
  );
  return (
    <div className={colour}>
      <div className="GamingCloth__corner">{corner}</div>
      {!isMini && (
        <>
          <div className="GamingCloth__pip">
            {parsed.value > 10 ? parsed.rank : parsed.glyph}
          </div>
          <div className="GamingCloth__corner GamingCloth__corner--far">
            {corner}
          </div>
        </>
      )}
    </div>
  );
}
