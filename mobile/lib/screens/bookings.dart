import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../theme.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  late Future<List<Booking>> _future = Api.instance.myBookings();

  Future<void> _reload() async {
    setState(() => _future = Api.instance.myBookings());
    await _future.catchError((_) => <Booking>[]);
  }

  Future<void> _cancel(Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: Text('${b.serviceName} on ${niceDate(b.date)} at ${time12(b.start)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel booking', style: TextStyle(color: badColor)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.instance.cancel(b.id);
      if (mounted) snack(context, 'Booking cancelled');
    } on ApiException catch (e) {
      if (mounted) snack(context, e.message);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<Booking>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return ListView(children: [
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(children: [
                  const Icon(Icons.cloud_off, size: 40, color: muted),
                  const SizedBox(height: 12),
                  Text('${snap.error}', textAlign: TextAlign.center, style: const TextStyle(color: muted)),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: _reload, child: const Text('Try again')),
                ]),
              ),
            ]);
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return ListView(children: const [
              Padding(
                padding: EdgeInsets.all(60),
                child: Column(children: [
                  Icon(Icons.event_available, size: 48, color: muted),
                  SizedBox(height: 12),
                  Text('No bookings yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  SizedBox(height: 4),
                  Text('Book your first appointment from the Book tab.', textAlign: TextAlign.center, style: TextStyle(color: muted)),
                ]),
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _BookingCard(booking: rows[i], onCancel: () => _cancel(rows[i])),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.onCancel});
  final Booking booking;
  final VoidCallback onCancel;

  static const _labels = {'booked': 'Upcoming', 'completed': 'Completed', 'cancelled': 'Cancelled', 'no_show': 'No-show'};

  Color get _color => switch (booking.status) {
        'completed' => okColor,
        'cancelled' => badColor,
        'no_show' => warnColor,
        _ => primary,
      };

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(booking.date);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(DateFormat('MMM').format(d).toUpperCase(),
                        style: const TextStyle(fontSize: 11, color: primary, fontWeight: FontWeight.w700)),
                    Text('${d.day}', style: const TextStyle(fontSize: 22, color: primary, fontWeight: FontWeight.w800)),
                  ]),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.serviceName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${time12(booking.start)} – ${time12(booking.end)} · ${money(booking.price)}',
                          style: const TextStyle(color: muted, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                  child: Text(_labels[booking.status] ?? booking.status,
                      style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            if (booking.note != null && booking.note!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: Text('“${booking.note}”', style: const TextStyle(fontSize: 13))),
            ],
            if (booking.status == 'booked') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close, size: 18, color: badColor),
                  label: const Text('Cancel', style: TextStyle(color: badColor)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
