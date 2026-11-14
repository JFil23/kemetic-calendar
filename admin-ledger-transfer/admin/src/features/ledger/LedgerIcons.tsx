export function LedgerIconDefs() {
  return (
    <svg
      aria-hidden="true"
      width="0"
      height="0"
      style={{ position: "absolute", overflow: "hidden" }}
    >
      <defs>
        <symbol id="search-icon" viewBox="0 0 24 24">
          <circle cx="10.8" cy="10.8" r="6.8" />
          <path d="m16 16 5 5" />
        </symbol>
        <symbol id="chevron-icon" viewBox="0 0 24 24">
          <path d="m6 9 6 6 6-6" />
        </symbol>
        <symbol id="close-icon" viewBox="0 0 24 24">
          <path d="M6 6 18 18 M18 6 6 18" />
        </symbol>
        <symbol id="lock-icon" viewBox="0 0 24 24">
          <rect x="5" y="10.5" width="14" height="10" rx="2" />
          <path d="M8 10.5V7a4 4 0 0 1 8 0v3.5" />
        </symbol>
        <symbol id="empty-icon" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="9" />
          <path d="M12 7v5 M12 16h.01" />
        </symbol>
      </defs>
    </svg>
  );
}

export function Icon({
  name,
  className = "ico",
}: {
  name: string;
  className?: string;
}) {
  return (
    <svg className={className} aria-hidden="true">
      <use href={`#${name}`} />
    </svg>
  );
}
