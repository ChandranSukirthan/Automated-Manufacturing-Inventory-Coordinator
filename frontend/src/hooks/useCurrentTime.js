import { useEffect, useState } from 'react';

// Time-dependent labels and delivery comparisons refresh without impure renders.
export default function useCurrentTime() {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 60_000);
    return () => clearInterval(timer);
  }, []);
  return now;
}
