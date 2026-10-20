import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import 'community_repository.dart';

String communityTime(dynamic milliseconds) {
  if (milliseconds is! num || milliseconds <= 0) return '';
  return DateFormat('dd/MM · HH:mm')
      .format(DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt()));
}

Json json(dynamic value) => Map<String, dynamic>.from(value as Map);
List<Json> rows(dynamic value) => (value as List? ?? []).map(json).toList();

Future<void> communityPush(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

void communityError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(CommunityRepository.error(error))));
}

Future<bool> communityConfirm(
  BuildContext context,
  String title,
  String body,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ??
    false;

class CommunityEmpty extends StatelessWidget {
  const CommunityEmpty(
    this.title,
    this.description, {
    super.key,
    this.icon = Icons.forum_outlined,
    this.action,
  });
  final String title, description;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.creamDark,
          child: Icon(icon, size: 30, color: AppColors.ink),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    ),
  );
}

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    backgroundColor: AppColors.creamDark,
    foregroundColor: AppColors.ink,
    child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase()),
  );
}

class CommunityPhoto extends StatefulWidget {
  const CommunityPhoto({
    super.key,
    required this.repo,
    required this.scope,
    this.action = 'image',
  });
  final CommunityRepository repo;
  final Json scope;
  final String action;
  @override
  State<CommunityPhoto> createState() => _CommunityPhotoState();
}

class _CommunityPhotoState extends State<CommunityPhoto> {
  late Future<Uint8List> future;
  @override
  void initState() {
    super.initState();
    future = widget.repo.image(widget.scope, action: widget.action);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: future,
    builder: (context, snap) {
      if (snap.hasError) {
        return TextButton.icon(
          onPressed: () => setState(
            () =>
                future = widget.repo.image(widget.scope, action: widget.action),
          ),
          icon: const Icon(Icons.refresh),
          label: const Text('Thử tải ảnh lại'),
        );
      }
      if (!snap.hasData) {
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(
          snap.data!,
          width: double.infinity,
          height: 240,
          fit: BoxFit.cover,
          gaplessPlayback: false,
          semanticLabel: 'Ảnh đính kèm',
          errorBuilder: (_, _, _) => const Text('Không đọc được ảnh.'),
        ),
      );
    },
  );
}

class CommunityForm extends StatefulWidget {
  const CommunityForm({
    super.key,
    required this.title,
    required this.fields,
    required this.submit,
    this.button = 'Lưu',
    this.description,
  });
  final String title, button;
  final String? description;
  final List<({String key, String label, int max, String initial})> fields;
  final Future<void> Function(Json values) submit;
  @override
  State<CommunityForm> createState() => _CommunityFormState();
}

class _CommunityFormState extends State<CommunityForm> {
  late final controllers = {
    for (final f in widget.fields)
      f.key: TextEditingController(text: f.initial),
  };
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.description != null) ...[
            Text(widget.description!),
            const SizedBox(height: 20),
          ],
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: controllers[f.key],
                maxLength: f.max,
                minLines: 1,
                maxLines: f.max > 100 ? 5 : 1,
                enabled: !busy,
                decoration: InputDecoration(labelText: f.label),
              ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    setState(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      await widget.submit({
                        for (final e in controllers.entries)
                          e.key: e.value.text.trim(),
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (mounted) {
                        setState(() => error = CommunityRepository.error(e));
                      }
                    } finally {
                      if (mounted) setState(() => busy = false);
                    }
                  },
            child: Text(busy ? 'Đang lưu…' : widget.button),
          ),
        ],
      ),
    ),
  );
}

class CommunityList extends StatefulWidget {
  const CommunityList({
    super.key,
    required this.load,
    required this.builder,
    required this.emptyTitle,
    required this.emptyDescription,
    this.header,
  });
  final Future<Json> Function(Json? cursor) load;
  final Widget Function(Json item, VoidCallback refresh) builder;
  final String emptyTitle, emptyDescription;
  final Widget? header;
  @override
  State<CommunityList> createState() => CommunityListState();
}

class CommunityListState extends State<CommunityList> {
  List<Json> items = [];
  Json? cursor;
  bool loading = true, more = false;
  String? error;
  int generation = 0;
  bool retryReset = true;
  void replaceItem(Json item) {
    setState(() {
      items = items.map((old) => old['id'] == item['id'] ? item : old).toList();
    });
  }

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh({bool clear = false}) =>
      fetch(reset: true, clear: clear);
  Future<void> fetch({bool reset = false, bool clear = false}) async {
    final ticket = reset ? ++generation : generation;
    if (!reset && more) return;
    setState(() {
      error = null;
      retryReset = reset;
      if (reset) {
        loading = true;
        if (clear) {
          items = [];
          cursor = null;
        }
      } else {
        more = true;
      }
    });
    try {
      final data = await widget.load(reset ? null : cursor);
      if (!mounted || ticket != generation) return;
      setState(() {
        items = reset
            ? rows(data['items'])
            : [...items, ...rows(data['items'])];
        cursor = data['cursor'] == null ? null : json(data['cursor']);
      });
    } catch (e) {
      if (mounted && ticket == generation) {
        setState(() {
          error = CommunityRepository.error(e);
          if (e is FirebaseFunctionsException &&
              [
                'permission-denied',
                'unauthenticated',
                'not-found',
              ].contains(e.code)) {
            items = [];
            cursor = null;
            retryReset = true;
          }
        });
      }
    } finally {
      if (mounted && ticket == generation) {
        setState(() {
          loading = false;
          more = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: refresh,
    child: ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: items.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return widget.header ?? const SizedBox.shrink();
        if (index <= items.length) {
          return widget.builder(items[index - 1], () {
            refresh();
          });
        }
        if (loading) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (error != null) {
          return CommunityEmpty(
            'Chưa tải được',
            error!,
            action: OutlinedButton(
              onPressed: () => fetch(reset: retryReset),
              child: const Text('Thử lại'),
            ),
          );
        }
        if (items.isEmpty && cursor == null) {
          return CommunityEmpty(widget.emptyTitle, widget.emptyDescription);
        }
        if (cursor != null) {
          return TextButton(
            onPressed: more ? null : () => fetch(),
            child: Text(more ? 'Đang tải…' : 'Xem thêm'),
          );
        }
        return const SizedBox.shrink();
      },
    ),
  );
}
