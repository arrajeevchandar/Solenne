import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/solenne_notice.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/profile_avatar.dart';
import '../../features/chat/chat_models.dart';
import '../../features/chat/chat_repository.dart';
import '../../features/journals/journal_entry.dart';
import '../../features/journals/journal_repository.dart';
import '../../features/social/social_models.dart';
import '../../features/social/social_repository.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import 'friends_screen.dart';

class ChatInboxCard extends ConsumerWidget {
  const ChatInboxCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final unread =
        conversations.value?.fold<int>(
          0,
          (total, conversation) =>
              total +
              conversation.unreadFor(
                ref.watch(firebaseAuthProvider).currentUser?.uid ?? '',
              ),
        ) ??
        0;
    final detail = conversations.isLoading
        ? 'Opening your conversations.'
        : conversations.hasError
        ? 'Your conversations could not be reached just now.'
        : unread > 0
        ? '$unread unread ${unread == 1 ? 'message' : 'messages'} waiting for you.'
        : 'Private conversations with people in your circle.';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: SolenneGlass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        borderRadius: 22,
        tint: AppColors.sapphire,
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.quicksand.withValues(alpha: 0.11),
                border: Border.all(
                  color: AppColors.quicksand.withValues(alpha: 0.48),
                ),
              ),
              child: const Icon(
                Icons.forum_outlined,
                color: AppColors.quicksand,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONVERSATIONS',
                    style: AppTextStyles.mono(
                      fontSize: 8,
                      color: AppColors.quicksand,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 12,
                      color: AppColors.shellstone.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 25),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.quicksand.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unread',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.mono(
                    fontSize: 8,
                    color: AppColors.quicksand,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.quicksand,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatInboxScreen extends ConsumerWidget {
  const ChatInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    return Scaffold(
      body: SolenneBackground(
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Spacer(),
                        Text(
                          'YOUR CIRCLE',
                          style: AppTextStyles.mono(
                            fontSize: 8,
                            color: AppColors.shellstone.withValues(alpha: 0.52),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Conversations',
                      style: AppTextStyles.display(fontSize: 36),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A quiet place to stay close to the people you trust.',
                      style: AppTextStyles.body(
                        fontSize: 13,
                        color: AppColors.shellstone.withValues(alpha: 0.72),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: conversations.when(
                        loading: () => const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        ),
                        error: (_, _) => const _ChatEmpty(
                          title: 'Conversations could not be opened.',
                          detail:
                              'Check your connection and return to Your circle.',
                        ),
                        data: (items) => items.isEmpty
                            ? const _ChatEmpty(
                                title: 'No conversations yet.',
                                detail:
                                    'Open a friend in Your circle when you are ready to say hello.',
                              )
                            : ListView.separated(
                                itemCount: items.length,
                                padding: const EdgeInsets.only(bottom: 18),
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, index) => _ConversationRow(
                                  conversation: items[index],
                                  uid: uid,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.conversation, required this.uid});

  final ChatConversation conversation;
  final String uid;

  @override
  Widget build(BuildContext context) {
    final friend = conversation.other(uid);
    final unread = conversation.unreadFor(uid);
    final preview = conversation.lastMessagePreview.isEmpty
        ? 'Begin a conversation.'
        : conversation.lastMessagePreview;
    return InkWell(
      onTap: () => Navigator.of(
        context,
      ).push(fadeThroughRoute(ChatScreen(conversationId: conversation.id))),
      borderRadius: BorderRadius.circular(20),
      child: SolenneGlass(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        borderRadius: 20,
        child: Row(
          children: [
            ProfileAvatar(photoUrl: friend.photoUrl, radius: 23),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          friend.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body(fontSize: 16),
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          DateFormat(
                            'h:mm a',
                          ).format(conversation.lastMessageAt!),
                          style: AppTextStyles.mono(fontSize: 7),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.shellstone.withValues(
                        alpha: unread > 0 ? 0.95 : 0.64,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 9),
              Container(
                constraints: const BoxConstraints(minWidth: 21),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.quicksand,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unread',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.mono(
                    fontSize: 7,
                    color: AppColors.royalBlue,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId, this.friendship});

  final String conversationId;
  final Friendship? friendship;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _composer = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _sending = false;
  bool _typing = false;
  bool _loadingOlder = false;
  bool _olderExhausted = false;
  final List<ChatMessage> _olderMessages = [];
  List<ChatMessage> _liveMessages = const [];
  String _lastLiveMessageId = '';
  String _acknowledgedInboundId = '';
  ProviderSubscription<AsyncValue<List<ChatMessage>>>? _messageSubscription;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageSubscription = ref.listenManual(
      chatMessagesProvider(widget.conversationId),
      (_, next) => next.whenData(_onLiveMessages),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageSubscription?.close();
    if (_typing) {
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .setTyping(widget.conversationId, false)
            .catchError((_) {}),
      );
    }
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 72) {
      _loadOlder();
    }
  }

  void _onLiveMessages(List<ChatMessage> items) {
    final previousLastId = _lastLiveMessageId;
    _liveMessages = items;
    _lastLiveMessageId = items.isEmpty ? '' : items.last.id;
    final liveIds = items.map((message) => message.id).toSet();
    _olderMessages.removeWhere((message) => liveIds.contains(message.id));

    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    ChatMessage? latestInbound;
    for (final message in items.reversed) {
      if (message.senderId != uid) {
        latestInbound = message;
        break;
      }
    }
    final conversation = ref
        .read(chatConversationProvider(widget.conversationId))
        .value;
    if (latestInbound != null &&
        conversation != null &&
        latestInbound.id != _acknowledgedInboundId &&
        conversation.unreadFor(uid) > 0) {
      _acknowledgedInboundId = latestInbound.id;
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .acknowledgeInbound(
              conversation: conversation,
              latestInbound: latestInbound,
            )
            .catchError((_) {}),
      );
    }
    if (items.isNotEmpty && previousLastId != _lastLiveMessageId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final position = _scrollController.position;
        final shouldFollow =
            previousLastId.isEmpty ||
            position.maxScrollExtent - position.pixels < 180;
        if (shouldFollow) {
          _scrollController.animateTo(
            position.maxScrollExtent,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || _olderExhausted || _liveMessages.isEmpty) return;
    final oldest = _olderMessages.isNotEmpty
        ? _olderMessages.first
        : _liveMessages.first;
    if (oldest.createdAt == null) return;
    setState(() => _loadingOlder = true);
    try {
      final previousExtent = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      final older = await ref
          .read(chatRepositoryProvider)
          .fetchOlderMessages(widget.conversationId, before: oldest.createdAt!);
      if (!mounted) return;
      final knownIds = {
        ..._olderMessages.map((message) => message.id),
        ..._liveMessages.map((message) => message.id),
      };
      setState(() {
        _olderMessages.insertAll(
          0,
          older.where((message) => knownIds.add(message.id)),
        );
        _olderExhausted = older.length < 50;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final addedExtent =
            _scrollController.position.maxScrollExtent - previousExtent;
        _scrollController.jumpTo(
          addedExtent.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          ),
        );
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Older messages could not be loaded.');
      }
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  List<ChatMessage> _allMessages(List<ChatMessage> live) {
    final byId = <String, ChatMessage>{
      for (final message in _olderMessages) message.id: message,
      for (final message in live) message.id: message,
    };
    final messages = byId.values.toList();
    messages.sort((left, right) {
      final byTime = (left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      return byTime != 0 ? byTime : left.id.compareTo(right.id);
    });
    return messages;
  }

  void _onChanged(String value) {
    final conversation = ref
        .read(chatConversationProvider(widget.conversationId))
        .value;
    if (conversation == null || !conversation.active) return;
    if (!_typing && value.trim().isNotEmpty) {
      _typing = true;
      unawaited(
        ref
            .read(chatRepositoryProvider)
            .setTyping(widget.conversationId, true)
            .catchError((_) {}),
      );
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), _clearTyping);
  }

  void _clearTyping() {
    if (!_typing) return;
    _typing = false;
    unawaited(
      ref
          .read(chatRepositoryProvider)
          .setTyping(widget.conversationId, false)
          .catchError((_) {}),
    );
  }

  Future<void> _send(Friendship? friendship) async {
    if (_sending || friendship == null) return;
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendText(friendship: friendship, text: text);
      _composer.clear();
      _clearTyping();
    } catch (error) {
      if (mounted) setState(() => _error = 'Your message could not be sent.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _shareJournal(Friendship? friendship) async {
    if (friendship == null || _sending) return;
    final entry = await showModalBottomSheet<JournalEntry>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _JournalPickerSheet(),
    );
    if (entry == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendJournalShare(
            friendship: friendship,
            entry: entry,
            includeTranscript: false,
          );
      if (mounted) {
        SolenneNotice.show(
          context,
          message: 'Reflection shared in this conversation.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'This reflection could not be shared.');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    final conversation = ref.watch(
      chatConversationProvider(widget.conversationId),
    );
    final messages = ref.watch(chatMessagesProvider(widget.conversationId));
    final relationships =
        ref.watch(relationshipsProvider).value ?? const <Friendship>[];
    final friendship =
        widget.friendship ??
        relationships
            .where(
              (item) =>
                  item.id == widget.conversationId && item.status == 'accepted',
            )
            .firstOrNull;
    final fallbackFriend = friendship?.other(uid);
    final currentConversation = conversation.value;
    final friend = currentConversation?.other(uid) ?? fallbackFriend;
    final typing = currentConversation?.isTyping(uid) ?? false;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SolenneBackground(
        child: SafeArea(
          child: Column(
            children: [
              _ChatHeader(
                friend: friend,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: messages.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  error: (_, _) => const _ChatEmpty(
                    title: 'This conversation could not be reached.',
                    detail:
                        'Check your connection, then return to Your circle.',
                  ),
                  data: (liveItems) {
                    final items = _allMessages(liveItems);
                    return items.isEmpty
                        ? const _ChatEmpty(
                            title: 'A quiet space to begin.',
                            detail: 'Send a small hello when you are ready.',
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                            itemCount: items.length + (_loadingOlder ? 1 : 0),
                            itemBuilder: (_, index) {
                              if (_loadingOlder && index == 0) {
                                return const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.2,
                                    ),
                                  ),
                                );
                              }
                              final itemIndex = index - (_loadingOlder ? 1 : 0);
                              final message = items[itemIndex];
                              final previous = itemIndex == 0
                                  ? null
                                  : items[itemIndex - 1];
                              final showDate =
                                  previous == null ||
                                  !_sameDay(
                                    previous.createdAt,
                                    message.createdAt,
                                  );
                              final otherId = currentConversation?.memberIds
                                  .where((memberId) => memberId != uid)
                                  .firstOrNull;
                              return Column(
                                children: [
                                  if (showDate)
                                    _DateSeparator(date: message.createdAt),
                                  _MessageRow(
                                    message: message,
                                    own: message.senderId == uid,
                                    conversationId: widget.conversationId,
                                    receipt: message.senderId == uid
                                        ? _receiptFor(
                                            message,
                                            currentConversation,
                                            otherId,
                                          )
                                        : '',
                                  ),
                                ],
                              );
                            },
                          );
                  },
                ),
              ),
              if (typing)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 7),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${friend?.displayName ?? 'Friend'} is typing...',
                      style: AppTextStyles.body(
                        fontSize: 11,
                        color: AppColors.shellstone.withValues(alpha: 0.65),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 7),
                  child: Text(
                    _error!,
                    style: AppTextStyles.body(
                      fontSize: 11,
                      color: AppColors.quicksand,
                    ),
                  ),
                ),
              _Composer(
                controller: _composer,
                sending: _sending,
                enabled: friendship != null,
                onChanged: _onChanged,
                onSend: () => _send(friendship),
                onShare: () => _shareJournal(friendship),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.friend, required this.onBack});

  final PublicProfile? friend;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 20, 12),
    child: Row(
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        ProfileAvatar(photoUrl: friend?.photoUrl, radius: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                friend?.displayName ?? 'Conversation',
                style: AppTextStyles.display(fontSize: 26),
              ),
              Text(
                friend?.username.isNotEmpty == true
                    ? '@${friend!.username}'
                    : 'YOUR CIRCLE',
                style: AppTextStyles.mono(
                  fontSize: 8,
                  color: AppColors.quicksand,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MessageRow extends ConsumerWidget {
  const _MessageRow({
    required this.message,
    required this.own,
    required this.conversationId,
    this.receipt = '',
  });

  final ChatMessage message;
  final bool own;
  final String conversationId;
  final String receipt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = message.createdAt == null
        ? ''
        : DateFormat('h:mm a').format(message.createdAt!);
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: GestureDetector(
            onLongPress: own && !message.deleted
                ? () => _confirmDelete(context, ref)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: own
                    ? AppColors.quicksand.withValues(alpha: 0.16)
                    : AppColors.sapphire.withValues(alpha: 0.36),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(own ? 18 : 4),
                  bottomRight: Radius.circular(own ? 4 : 18),
                ),
                border: Border.all(
                  color: (own ? AppColors.quicksand : AppColors.swanWing)
                      .withValues(alpha: own ? 0.44 : 0.18),
                ),
              ),
              child: message.deleted
                  ? Text(
                      'Message removed',
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.shellstone.withValues(alpha: 0.62),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.isJournalShare)
                          _ChatSharedJournal(message: message)
                        else
                          SelectableText(
                            message.body,
                            style: AppTextStyles.body(fontSize: 13),
                          ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            receipt.isEmpty ? time : '$time  $receipt',
                            style: AppTextStyles.mono(fontSize: 7),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.royalBlue,
        title: Text(
          'Remove message?',
          style: AppTextStyles.display(fontSize: 28),
        ),
        content: Text(
          'This removes the message for both people.',
          style: AppTextStyles.body(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (remove == true) {
      await ref
          .read(chatRepositoryProvider)
          .deleteForEveryone(conversationId: conversationId, message: message);
    }
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime? date;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Expanded(
          child: Divider(color: AppColors.swanWing.withValues(alpha: 0.1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            date == null ? 'TODAY' : DateFormat('EEE, d MMM').format(date!),
            style: AppTextStyles.mono(
              fontSize: 7,
              color: AppColors.shellstone.withValues(alpha: 0.54),
            ),
          ),
        ),
        Expanded(
          child: Divider(color: AppColors.swanWing.withValues(alpha: 0.1)),
        ),
      ],
    ),
  );
}

bool _sameDay(DateTime? first, DateTime? second) =>
    first != null &&
    second != null &&
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _receiptFor(
  ChatMessage message,
  ChatConversation? conversation,
  String? recipientId,
) {
  final sentAt = message.createdAt;
  if (sentAt == null) return 'SENDING';
  if (conversation == null || recipientId == null) return 'SENT';
  final readAt = conversation.readFor(recipientId);
  if (readAt != null && !readAt.isBefore(sentAt)) return 'SEEN';
  final deliveredAt = conversation.deliveredFor(recipientId);
  if (deliveredAt != null && !deliveredAt.isBefore(sentAt)) return 'DELIVERED';
  return 'SENT';
}

class _ChatSharedJournal extends ConsumerWidget {
  const _ChatSharedJournal({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final share = ref.watch(chatShareProvider(message.shareId));
    return share.when(
      loading: () => const SizedBox(
        width: 120,
        height: 36,
        child: Center(child: CircularProgressIndicator(strokeWidth: 1.2)),
      ),
      error: (_, _) => _UnavailableShare(),
      data: (value) => value == null
          ? _UnavailableShare()
          : InkWell(
              onTap: () => Navigator.of(
                context,
              ).push(fadeThroughRoute(SharedJournalScreen(share: value))),
              borderRadius: BorderRadius.circular(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_stories_outlined,
                    size: 18,
                    color: AppColors.quicksand,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      value.entry.displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _UnavailableShare extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text(
    'Shared reflection is no longer available.',
    style: AppTextStyles.body(
      fontSize: 12,
      color: AppColors.shellstone.withValues(alpha: 0.66),
      fontStyle: FontStyle.italic,
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onChanged,
    required this.onSend,
    required this.onShare,
  });

  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      16,
      8,
      16,
      14 + MediaQuery.of(context).padding.bottom,
    ),
    child: SolenneGlass(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      borderRadius: 24,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Share a journal',
            onPressed: enabled && !sending ? onShare : null,
            icon: const Icon(
              Icons.auto_stories_outlined,
              color: AppColors.quicksand,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled && !sending,
              onChanged: onChanged,
              maxLength: 2000,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.body(fontSize: 13),
              decoration: InputDecoration(
                counterText: '',
                hintText: enabled
                    ? 'Write a message...'
                    : 'This chat is no longer available.',
                hintStyle: AppTextStyles.body(
                  fontSize: 12,
                  color: AppColors.shellstone.withValues(alpha: 0.48),
                  fontStyle: FontStyle.italic,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Send message',
            onPressed: enabled && !sending ? onSend : null,
            icon: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 1.4),
                  )
                : const Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.quicksand,
                  ),
          ),
        ],
      ),
    ),
  );
}

class _JournalPickerSheet extends ConsumerWidget {
  const _JournalPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journals = ref.watch(journalStreamProvider);
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        decoration: const BoxDecoration(
          color: AppColors.royalBlue,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share a reflection',
              style: AppTextStyles.display(fontSize: 30),
            ),
            const SizedBox(height: 4),
            Text(
              'Only completed reflections can be shared. The transcript stays private here.',
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.72),
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 15),
            Expanded(
              child: journals.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 1.4),
                ),
                error: (_, _) => const Center(
                  child: Text('Your journals could not be opened.'),
                ),
                data: (items) {
                  final eligible = items
                      .where((item) => item.analysisStatus == 'complete')
                      .toList();
                  if (eligible.isEmpty) {
                    return Center(
                      child: Text(
                        'Complete a reflection before sharing it here.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body(fontSize: 13),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: eligible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (_, index) {
                      final entry = eligible[index];
                      return InkWell(
                        onTap: () => Navigator.of(context).pop(entry),
                        borderRadius: BorderRadius.circular(18),
                        child: SolenneGlass(
                          padding: const EdgeInsets.all(13),
                          borderRadius: 18,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_stories_outlined,
                                color: AppColors.quicksand,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.displayTitle,
                                  style: AppTextStyles.body(fontSize: 14),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_rounded, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatEmpty extends StatelessWidget {
  const _ChatEmpty({required this.title, required this.detail});
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: SolenneGlass(
        padding: const EdgeInsets.all(22),
        borderRadius: 22,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              color: AppColors.quicksand,
              size: 30,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(fontSize: 25),
            ),
            const SizedBox(height: 5),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
