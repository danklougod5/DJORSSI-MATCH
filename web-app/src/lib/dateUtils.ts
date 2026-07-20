/**
 * Formats a date string (e.g. "2026-07-20" or "20/07/2026") into a long French date format:
 * e.g. "Lundi 20 juillet 2026".
 */
export const formatLongDate = (dateStr: string | null | undefined): string => {
  if (!dateStr || typeof dateStr !== 'string') return '';
  const trimmed = dateStr.trim();
  if (!trimmed) return '';

  // Try parsing DD/MM/YYYY
  const slashParts = trimmed.split('/');
  if (slashParts.length === 3) {
    const day = parseInt(slashParts[0], 10);
    const month = parseInt(slashParts[1], 10) - 1;
    const year = parseInt(slashParts[2], 10);
    const d = new Date(year, month, day);
    if (!isNaN(d.getTime())) {
      return formatDateToLongFrench(d);
    }
  }

  // Try parsing ISO or other standard format
  const d = new Date(trimmed);
  if (!isNaN(d.getTime())) {
    return formatDateToLongFrench(d);
  }

  // Fallback to original string if not parseable
  return dateStr;
};

const formatDateToLongFrench = (date: Date): string => {
  try {
    const formatted = date.toLocaleDateString('fr-FR', {
      weekday: 'long',
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });
    // Capitalize the first letter of the weekday (e.g. "Lundi 20 juillet 2026")
    return formatted.charAt(0).toUpperCase() + formatted.slice(1);
  } catch (e) {
    return date.toDateString();
  }
};

/**
 * Converts any parseable date string (including DD/MM/YYYY) to standard YYYY-MM-DD for input[type="date"]
 */
export const formatToIsoDate = (dateStr: string | null | undefined): string => {
  if (!dateStr || typeof dateStr !== 'string') return '';
  const trimmed = dateStr.trim();
  
  // Try DD/MM/YYYY
  const parts = trimmed.split('/');
  if (parts.length === 3) {
    const day = parts[0].padStart(2, '0');
    const month = parts[1].padStart(2, '0');
    const year = parts[2];
    return `${year}-${month}-${day}`;
  }

  // Try parsing directly
  const d = new Date(trimmed);
  if (!isNaN(d.getTime())) {
    const yyyy = d.getFullYear();
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  return '';
};
