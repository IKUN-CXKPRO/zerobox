import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oronbox/src/app/generated/app_localizations.dart';
import 'package:oronbox/src/app/widgets/page_container.dart';
import 'package:oronbox/src/app/widgets/sys_app_bar.dart';
import 'package:oronbox/src/core/constants/style_constants.dart';
import 'package:oronbox/src/features/settings/services/oronbox_support_api.dart';

class FeedbackTarget {
  const FeedbackTarget({
    required this.source,
    required this.id,
    required this.name,
    this.url = '',
  });

  final String source, id, name, url;
}

class FeedbackPage extends ConsumerStatefulWidget {
  const FeedbackPage({super.key, this.target});

  final FeedbackTarget? target;

  @override
  ConsumerState<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends ConsumerState<FeedbackPage> {
  List<FeedbackTicket>? _tickets;
  FeedbackTicket? _selected;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _reload();
    if (widget.target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _compose());
    }
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final tickets = await ref.read(oronBoxSupportApiProvider).feedback();
      FeedbackTicket? selected;
      if (_selected != null) {
        selected = tickets
            .where((item) => item.id == _selected!.id)
            .firstOrNull;
        if (selected != null) {
          selected = await ref
              .read(oronBoxSupportApiProvider)
              .feedbackDetail(selected.id);
        }
      }
      if (!mounted) return;
      setState(() {
        _tickets = tickets;
        _selected = selected;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _open(FeedbackTicket ticket) async {
    setState(() => _selected = ticket);
    try {
      final detail = await ref
          .read(oronBoxSupportApiProvider)
          .feedbackDetail(ticket.id);
      if (mounted && _selected?.id == ticket.id) {
        setState(() => _selected = detail);
      }
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _compose() async {
    final created = await showDialog<FeedbackTicket>(
      context: context,
      builder: (context) => _FeedbackComposer(target: widget.target),
    );
    if (created == null || !mounted) return;
    setState(() => _selected = created);
    await _reload();
    if (mounted) setState(() => _selected = created);
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(
          widget.target == null ? l10n.feedbackTitle : l10n.reportResource,
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _reload,
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _compose,
            tooltip: l10n.feedbackNewTicket,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 840;
          if (!wide && _selected != null) {
            return _TicketDetail(
              ticket: _selected!,
              onBack: () => setState(() => _selected = null),
              onUpdated: (ticket) {
                setState(() => _selected = ticket);
                _reload();
              },
            );
          }
          final list = _TicketList(
            tickets: _tickets ?? const [],
            selectedId: _selected?.id,
            loading: _loading,
            error: _error,
            onRetry: _reload,
            onSelect: _open,
            onCreate: _compose,
          );
          return PageContainer(
            maxWidth: 1200,
            padding: const EdgeInsets.all(StyleConstants.pagePadding),
            child: wide
                ? Row(
                    children: [
                      SizedBox(width: 360, child: list),
                      const SizedBox(width: 24),
                      Expanded(
                        child: _selected == null
                            ? _TicketPlaceholder(onCreate: _compose)
                            : _TicketDetail(
                                ticket: _selected!,
                                onUpdated: (ticket) {
                                  setState(() => _selected = ticket);
                                  _reload();
                                },
                              ),
                      ),
                    ],
                  )
                : list,
          );
        },
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.selectedId,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onSelect,
    required this.onCreate,
  });

  final List<FeedbackTicket> tickets;
  final String? selectedId;
  final bool loading;
  final Object? error;
  final VoidCallback onRetry;
  final ValueChanged<FeedbackTicket> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (loading && tickets.isEmpty) {
      return Center(child: Text(l10n.feedbackLoading));
    }
    if (error != null && tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    if (tickets.isEmpty) {
      return _TicketPlaceholder(onCreate: onCreate);
    }
    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tickets.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final ticket = tickets[index];
          return ListTile(
            selected: selectedId == ticket.id,
            selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Icon(
              ticket.kind == 'report'
                  ? Icons.flag_outlined
                  : Icons.chat_bubble_outline,
            ),
            title: Text(ticket.subject, maxLines: 1),
            subtitle: Text(
              ticket.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: _TicketStatus(status: ticket.status, compact: true),
            onTap: () => onSelect(ticket),
          );
        },
      ),
    );
  }
}

class _TicketDetail extends ConsumerStatefulWidget {
  const _TicketDetail({
    required this.ticket,
    required this.onUpdated,
    this.onBack,
  });

  final FeedbackTicket ticket;
  final ValueChanged<FeedbackTicket> onUpdated;
  final VoidCallback? onBack;

  @override
  ConsumerState<_TicketDetail> createState() => _TicketDetailState();
}

class _TicketDetailState extends ConsumerState<_TicketDetail> {
  final _reply = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _reply.text.trim();
    if (message.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final ticket = await ref
          .read(oronBoxSupportApiProvider)
          .replyFeedback(widget.ticket.id, message);
      _reply.clear();
      widget.onUpdated(ticket);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final ticket = widget.ticket;
    final canReply = ticket.status != 'closed' && ticket.status != 'dismissed';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Row(
            children: [
              if (widget.onBack != null)
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.subject,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    _TicketStatus(status: ticket.status),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              _MessageBubble(
                author: l10n.feedbackYou,
                message: ticket.message,
                time: ticket.createdAt,
                mine: true,
              ),
              for (final reply in ticket.replies)
                _MessageBubble(
                  author: reply.author,
                  message: reply.message,
                  time: reply.createdAt,
                ),
              if (ticket.resolution.isNotEmpty &&
                  !ticket.replies.any(
                    (reply) => reply.message == ticket.resolution,
                  ))
                _MessageBubble(
                  author: l10n.feedbackResolution,
                  message: ticket.resolution,
                  time: ticket.updatedAt,
                ),
            ],
          ),
        ),
        if (canReply)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        minLines: 1,
                        maxLines: 5,
                        decoration: InputDecoration(
                          hintText: l10n.feedbackReplyHint,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      icon: Icon(
                        _sending
                            ? Icons.hourglass_top_rounded
                            : Icons.send_outlined,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.feedbackConversationClosed),
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.author,
    required this.message,
    required this.time,
    this.mine = false,
  });

  final String author, message;
  final DateTime time;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.fromLTRB(16, 5, 16, 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: mine ? colors.primaryContainer : colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(author, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SelectableText(message),
            const SizedBox(height: 6),
            Text(
              MaterialLocalizations.of(context).formatShortDate(time.toLocal()),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketStatus extends StatelessWidget {
  const _TicketStatus({required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (label, color) = switch (status) {
      'open' => (l10n.feedbackOpen, Theme.of(context).colorScheme.primary),
      'investigating' => (
        l10n.feedbackProcessing,
        Theme.of(context).colorScheme.tertiary,
      ),
      'replied' => (
        l10n.feedbackReplied,
        Theme.of(context).colorScheme.secondary,
      ),
      'resolved' => (l10n.feedbackResolved, Colors.green),
      'dismissed' => (
        l10n.feedbackDismissed,
        Theme.of(context).colorScheme.error,
      ),
      'closed' => (l10n.feedbackClosed, Theme.of(context).colorScheme.outline),
      _ => (status, Theme.of(context).colorScheme.outline),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class _TicketPlaceholder extends StatelessWidget {
  const _TicketPlaceholder({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(l10n.noFeedback),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(l10n.feedbackNewTicket),
          ),
        ],
      ),
    );
  }
}

class _FeedbackComposer extends ConsumerStatefulWidget {
  const _FeedbackComposer({this.target});

  final FeedbackTarget? target;

  @override
  ConsumerState<_FeedbackComposer> createState() => _FeedbackComposerState();
}

class _FeedbackComposerState extends ConsumerState<_FeedbackComposer> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    if (widget.target != null) _subject.text = widget.target!.name;
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty ||
        _message.text.trim().isEmpty ||
        _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final ticket = await ref
          .read(oronBoxSupportApiProvider)
          .createFeedback(
            kind: widget.target == null ? 'feedback' : 'report',
            subject: _subject.text.trim(),
            message: _message.text.trim(),
            targetSource: widget.target?.source ?? '',
            targetId: widget.target?.id ?? '',
            targetUrl: widget.target?.url ?? '',
          );
      if (mounted) Navigator.pop(context, ticket);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(
        widget.target == null ? l10n.feedbackNewTicket : l10n.reportResource,
      ),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.target case final target?)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: Text(target.name),
                subtitle: Text('${target.source} · ${target.id}'),
              ),
            TextField(
              controller: _subject,
              maxLength: 120,
              autofocus: widget.target == null,
              decoration: InputDecoration(labelText: l10n.feedbackSubject),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLength: 10000,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: widget.target == null
                    ? l10n.feedbackMessage
                    : l10n.reportReason,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          onPressed: _sending ? null : _submit,
          icon: Icon(
            _sending ? Icons.hourglass_top_rounded : Icons.send_outlined,
          ),
          label: Text(l10n.submit),
        ),
      ],
    );
  }
}
