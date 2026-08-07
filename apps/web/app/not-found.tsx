import { messages } from '@/lib/messages';

// Reached by a kitchen with nothing on offer, and by a Meal that is not on
// offer. Deliberately the same page for both: telling someone which of the two
// happened would disclose that a kitchen exists and is closed, which is more
// than a stranger is owed.
export default function NotFound() {
  return (
    <main>
      <p className="empty">{messages().notFound}</p>
    </main>
  );
}
