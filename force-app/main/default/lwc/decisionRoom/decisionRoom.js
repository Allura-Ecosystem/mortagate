import { LightningElement, api } from 'lwc';

/**
 * c-decision-room — Screen 5. Pike's "Active state": one panel, an event feed.
 *
 * The pending empty state is never a bare timeline (that reads as abandonment).
 * It shows a single amber heartbeat pulse — the only motion on the screen — and
 * one reassuring line. The pulse honors prefers-reduced-motion.
 */
export default class DecisionRoom extends LightningElement {
    // [{ id, label, timestamp }] newest-last, rendered chronologically.
    @api events = [];

    get hasEvents() {
        return Array.isArray(this.events) && this.events.length > 0;
    }

    get displayEvents() {
        if (!this.hasEvents) return [];
        return this.events.map((e, i) => ({
            id: e.id || `evt-${i}`,
            label: e.label,
            timestamp: e.timestamp,
            isLast: i === this.events.length - 1
        }));
    }
}
