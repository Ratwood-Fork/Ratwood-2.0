import type { TableEvent } from './types';

type Props = {
  events: TableEvent[];
};

/** What happened at the table, newest first */
export function TableLog(props: Props) {
  const { events } = props;
  if (!events?.length) {
    return (
      <div className="GamingCloth__logEmpty">Nothing has happened yet</div>
    );
  }
  const newestFirst = [...events].sort((a, b) => b.seq - a.seq);
  return (
    <div className="GamingCloth__log">
      {newestFirst.map((event) => (
        <div key={event.seq} className="GamingCloth__logLine">
          {event.text}
        </div>
      ))}
    </div>
  );
}
