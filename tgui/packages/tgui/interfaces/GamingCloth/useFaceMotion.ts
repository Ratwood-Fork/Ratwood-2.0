import { type AnimationEvent, useEffect, useRef, useState } from 'react';

import { type FaceChange, type FaceMotion, nextFaceMotion } from './motion';

/**
 * Holds a card face's hover and hop motion as the gallery's thumbnails do.
 * Each motion is a class whose animation plays once, cleared when it ends,
 * so nothing is left running.
 */
export function useFaceMotion(isSelected: boolean) {
  const [motion, setMotion] = useState<FaceMotion | null>(null);
  const isHovered = useRef(false);
  const wasSelected = useRef(isSelected);

  const change = (what: FaceChange) =>
    setMotion((current) =>
      nextFaceMotion(current, what, isSelected, isHovered.current),
    );

  useEffect(() => {
    if (isSelected === wasSelected.current) {
      return;
    }
    wasSelected.current = isSelected;
    change(isSelected ? 'select' : 'deselect');
  }, [isSelected]);

  return {
    motion,
    handleEnter: () => {
      isHovered.current = true;
      change('enter');
    },
    handleLeave: () => {
      isHovered.current = false;
      change('leave');
    },
    // An animation inside the face bubbles here too, and is not the face's own
    handleAnimationEnd: (event: AnimationEvent<HTMLElement>) => {
      if (event.target === event.currentTarget) {
        change('end');
      }
    },
  };
}
