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

export const parseFlexibleDate = (
  dateStr: string | null | undefined,
): Date | null => {
  if (!dateStr || typeof dateStr !== 'string') return null;

  const trimmed = dateStr.trim();
  if (!trimmed) return null;

  const slashParts = trimmed.split('/');
  if (slashParts.length === 3) {
    const day = parseInt(slashParts[0], 10);
    const month = parseInt(slashParts[1], 10) - 1;
    const year = parseInt(slashParts[2], 10);
    const parsed = new Date(year, month, day);

    if (!isNaN(parsed.getTime())) {
      parsed.setHours(23, 59, 59, 999);
      return parsed;
    }
  }

  const parsed = new Date(trimmed);
  if (isNaN(parsed.getTime())) return null;

  if (/^\d{4}-\d{2}-\d{2}$/.test(trimmed)) {
    parsed.setHours(23, 59, 59, 999);
  }

  return parsed;
};

export const getEffectiveJobExpiryDate = (job: {
  deadline?: string | null;
  created_at?: string | null;
}): Date | null => {
  const explicitDeadline = parseFlexibleDate(job.deadline);
  if (explicitDeadline) return explicitDeadline;

  const createdAt = parseFlexibleDate(job.created_at);
  if (!createdAt) return null;

  const fallback = new Date(createdAt);
  fallback.setDate(fallback.getDate() + 21);
  fallback.setHours(23, 59, 59, 999);
  return fallback;
};

export const isJobExpired = (
  job: {
    deadline?: string | null;
    created_at?: string | null;
  },
  now: Date = new Date(),
): boolean => {
  const expiryDate = getEffectiveJobExpiryDate(job);
  return expiryDate ? expiryDate.getTime() < now.getTime() : false;
};

export const formatEffectiveJobDeadline = (job: {
  deadline?: string | null;
  created_at?: string | null;
}): string => {
  const expiryDate = getEffectiveJobExpiryDate(job);
  return expiryDate ? formatDateToLongFrench(expiryDate) : '';
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
