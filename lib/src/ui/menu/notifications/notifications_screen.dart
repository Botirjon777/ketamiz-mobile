import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../model/api/broadcast_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/utils.dart';
import '../../widgets/containers/leading_back.dart';
import '../../widgets/texts/text_16h_500w.dart';
import 'notification_detail_screen.dart';

/// Notifications feed, backed by the `GET /broadcasts` endpoint. Tapping a row
/// opens the full message ([NotificationDetailScreen]).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Repository _repository = Repository();

  bool _loading = true;
  bool _hasError = false;
  List<BroadcastModel> _items = const [];
  String _lang = 'uz';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _hasError = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language') ?? 'uz';

    final response = await _repository.fetchBroadcasts();
    if (!mounted) return;

    if (response.isSuccess) {
      setState(() {
        _lang = lang;
        _items = BroadcastModel.listFromResult(response.result);
        _loading = false;
      });
    } else {
      setState(() {
        _hasError = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("home.notifications")),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: AppTheme.purple,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
        ),
      );
    }

    if (_hasError && _items.isEmpty) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      // ListView keeps pull-to-refresh available on the empty state.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: _buildEmptyState(),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _NotificationTile(
        broadcast: _items[i],
        lang: _lang,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationDetailScreen(broadcast: _items[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppTheme.red.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_off_rounded,
                        size: 40, color: AppTheme.red),
                  ),
                  const SizedBox(height: 20),
                  Text16h500w(title: translate("home.notifications_error")),
                  const SizedBox(height: 6),
                  Text(
                    translate("auth.connection_failed_msg"),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                      color: AppTheme.gray,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _load,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.purple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        translate("home.retry"),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 40, color: AppTheme.purple),
            ),
            const SizedBox(height: 20),
            Text16h500w(title: translate("home.no_notifications")),
            const SizedBox(height: 6),
            Text(
              translate("home.no_notifications_msg"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppTheme.gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.broadcast,
    required this.lang,
    required this.onTap,
  });

  final BroadcastModel broadcast;
  final String lang;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = broadcast.localizedTitle(lang);
    final body = broadcast.localizedBody(lang);
    final date = broadcast.createdAt;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.notifications_rounded,
                  size: 20, color: AppTheme.purple),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text16h500w(title: title)),
                      if (date != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          Utils.dateFormat(date),
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.gray,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        height: 1.4,
                        color: AppTheme.gray,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.gray),
          ],
        ),
      ),
    );
  }
}
