export function formatDate(value: string | null | undefined) {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat(undefined, {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(date);
}

export function formatMoney(value: number | string | null | undefined) {
  const parsed = Number(value ?? 0);
  if (!Number.isFinite(parsed)) return "$0.00";
  return new Intl.NumberFormat(undefined, {
    style: "currency",
    currency: "USD",
    minimumFractionDigits: parsed < 1 ? 4 : 2,
    maximumFractionDigits: 4,
  }).format(parsed);
}
