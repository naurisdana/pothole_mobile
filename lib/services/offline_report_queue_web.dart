class OfflineQueueItem {
  const OfflineQueueItem({required this.id, required this.payload});
  final int id;
  final dynamic payload;
}

class OfflineReportQueue {
  static final List<OfflineQueueItem> _items = [];
  static int _nextId = 1;

  Future<int> enqueue(dynamic payload) async {
    final item = OfflineQueueItem(id: _nextId++, payload: payload);
    _items.add(item);
    return item.id;
  }

  Future<List<OfflineQueueItem>> pending() async => List.unmodifiable(_items);

  Future<void> remove(OfflineQueueItem item) async {
    _items.removeWhere((queued) => queued.id == item.id);
  }

  Future<int> count() async => _items.length;
}
