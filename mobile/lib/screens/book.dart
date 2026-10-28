import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../theme.dart';

class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.onBooked});
  final VoidCallback onBooked;

  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  late Future<List<Service>> _services = Api.instance.services();
  Service? _service;
  late DateTime _date = DateTime.now();
  Future<List<String>>? _slots;
  String? _time;
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _loadSlots() {
    _time = null;
    _slots = Api.instance.slots(isoDate(_date), _service!.id);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await Api.instance.book(_service!.id, isoDate(_date), _time!, _note.text.trim());
      if (!mounted) return;
      setState(() {
        _service = null;
        _slots = null;
        _time = null;
        _note.clear();
      });
      widget.onBooked();
    } on ApiException catch (e) {
      if (!mounted) return;
      snack(context, e.message);
      setState(_loadSlots);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Service>>(
      future: _services,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _Retry(message: '${snap.error}', onRetry: () => setState(() => _services = Api.instance.services()));
        }
        final services = snap.data!;
        if (services.isEmpty) return const Center(child: Text('No services available yet.'));
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const _SectionTitle('1. Choose a service'),
                  for (final s in services) ...[
                    _ServiceTile(
                      service: s,
                      selected: _service?.id == s.id,
                      onTap: () => setState(() {
                        _service = s;
                        _loadSlots();
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (_service != null) ...[
                    const SizedBox(height: 14),
                    const _SectionTitle('2. Pick a date'),
                    _dateStrip(),
                    const SizedBox(height: 18),
                    const _SectionTitle('3. Pick a time'),
                    _slotGrid(),
                    if (_time != null) ...[
                      const SizedBox(height: 18),
                      TextField(
                        controller: _note,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Note (optional)'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            if (_service != null && _time != null) _confirmBar(),
          ],
        );
      },
    );
  }

  Widget _dateStrip() {
    final today = DateTime.now();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 21,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = DateTime(today.year, today.month, today.day + i);
          final sel = isoDate(d) == isoDate(_date);
          return GestureDetector(
            onTap: () => setState(() {
              _date = d;
              _loadSlots();
            }),
            child: Container(
              width: 62,
              decoration: BoxDecoration(
                color: sel ? primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? primary : line, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('E').format(d).toUpperCase(),
                      style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : muted, fontWeight: FontWeight.w600)),
                  Text('${d.day}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: sel ? Colors.white : ink)),
                  Text(DateFormat('MMM').format(d),
                      style: TextStyle(fontSize: 11, color: sel ? Colors.white70 : muted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _slotGrid() {
    return FutureBuilder<List<String>>(
      future: _slots,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return _Retry(message: '${snap.error}', onRetry: () => setState(_loadSlots));
        }
        final slots = snap.data!;
        if (slots.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No free slots on this day. Try another date.', style: TextStyle(color: muted))),
            ),
          );
        }
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final t in slots)
              ChoiceChip(
                label: Text(time12(t)),
                selected: _time == t,
                showCheckmark: false,
                selectedColor: primary,
                labelStyle: TextStyle(color: _time == t ? Colors.white : ink, fontWeight: FontWeight.w600),
                backgroundColor: Colors.white,
                side: BorderSide(color: _time == t ? primary : line, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                onSelected: (_) => setState(() => _time = t),
              ),
          ],
        );
      },
    );
  }

  Widget _confirmBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_service!.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text('${DateFormat('d MMM').format(_date)} · ${time12(_time!)} · ${money(_service!.price)}',
                      style: const TextStyle(color: muted, fontSize: 13)),
                ],
              ),
            ),
            SizedBox(
              width: 150,
              child: FilledButton(
                onPressed: _busy ? null : _confirm,
                child: _busy
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Confirm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      );
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.selected, required this.onTap});
  final Service service;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? primary : line, width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (service.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(service.description, style: const TextStyle(color: muted, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.schedule, size: 15, color: muted),
                    const SizedBox(width: 4),
                    Text(duration(service.durationMin), style: const TextStyle(color: muted, fontSize: 13)),
                  ]),
                ],
              ),
            ),
            Text(money(service.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primary)),
          ],
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40, color: muted),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
