import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../model/api/broadcast_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/utils.dart';
import '../../widgets/containers/leading_back.dart';
import '../../widgets/texts/text_16h_500w.dart';

/// Full view of a single broadcast message. The list already hands over a
/// [broadcast] so content shows instantly; the screen still refetches
/// `GET /broadcast/{id}` in the background to pick up the freshest copy.
class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({super.key, required this.broadcast});

  final BroadcastModel broadcast;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  final Repository _repository = Repository();

  late BroadcastModel _broadcast = widget.broadcast;
  String _lang = 'uz';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('language') ?? 'uz';
    if (mounted) setState(() => _lang = lang);

    if (widget.broadcast.id == 0) return;
    final response = await _repository.fetchBroadcast(widget.broadcast.id);
    if (!mounted) return;
    if (response.isSuccess) {
      final fresh = BroadcastModel.fromResult(response.result);
      if (fresh != null && fresh.id != 0) {
        setState(() => _broadcast = fresh);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _broadcast.localizedTitle(_lang);
    final body = _broadcast.localizedBody(_lang);
    final date = _broadcast.createdAt;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("home.notifications")),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.notifications_rounded,
                    size: 24, color: AppTheme.purple),
              ),
              const SizedBox(width: 12),
              if (date != null)
                Text(
                  '${Utils.dateFormat(date)} • ${Utils.timeFormat(date)}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.gray,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: AppTheme.black,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.6,
                color: AppTheme.dark,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
