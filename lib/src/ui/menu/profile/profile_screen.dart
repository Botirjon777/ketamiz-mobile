import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ketamiz/src/ui/auth/login_screen.dart';
import 'package:ketamiz/src/ui/dialogs/bottom_dialog.dart';
import 'package:ketamiz/src/ui/dialogs/center_dialog.dart';
import 'package:ketamiz/src/ui/dialogs/snack_bar.dart';
import 'package:ketamiz/src/ui/menu/new_ketamiz/add_docs_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/change_password_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/edit_profile_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/my_vehicles_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/support_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/terms_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/top_up_screen.dart';
import 'package:ketamiz/src/ui/menu/profile/transaction_history_screen.dart';
import 'package:ketamiz/src/ui/widgets/texts/text_16h_500w.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../bloc/profile_bloc.dart';
import '../../../model/api/get_user_model.dart';
import '../../../model/settings_model.dart';
import '../../../resources/repository.dart';
import '../../../services/push_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/image_helper.dart';
import '../../../utils/nav_constants.dart';
import '../../../utils/secure_storage.dart';
import '../../../utils/utils.dart';
import '../../widgets/containers/settings_container.dart';
import '../notifications/notifications_screen.dart';
import '../../widgets/notification_button.dart';
import '../../widgets/texts/text_14h_400w.dart';

const _kLanguages = [
  {'code': 'uz', 'name': "O'zbek", 'flag': '🇺🇿'},
  {'code': 'ru', 'name': 'Русский', 'flag': '🇷🇺'},
  {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
];

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String balance = "";
  String _myImage = '';
  String _localAvatarPath = '';
  String _myName = '';
  String _myPhone = '';
  String _myEmail = '';
  String _myFatherName = '';
  bool _isDriver = false;
  String _verificationStatus = 'none'; // none | pending | approved | rejected
  String _langName = "O'zbek";
  bool _isUploadingAvatar = false;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await blocProfile.fetchMe();
    await getBalance();
    await _getInfo();
  }

  /// Email and father's name are no longer asked at registration — prompt the
  /// user to fill whichever is still missing from their profile.
  bool get _needsProfileCompletion =>
      _myEmail.trim().isEmpty || _myFatherName.trim().isEmpty;

  /// First letters of the name, used when no avatar image is set.
  String get _initials {
    final parts = _myName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text16h500w(title: translate("profile.my_profile")),
        centerTitle: true,
        actions: [_buildNotificationBell()],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppTheme.purple,
            onRefresh: _refresh,
            child: ListView(
          padding: const EdgeInsets.only(
            top: 8,
            bottom: kNavBarTotalPadding,
            left: 16,
            right: 16,
          ),
          children: [
            _buildProfileCard(),
            if (_needsProfileCompletion) ...[
              const SizedBox(height: 12),
              _buildCompleteProfileBanner(),
            ],
            const SizedBox(height: 16),
            _buildBalanceCard(),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TransactionHistoryScreen(),
                ),
              ),
              child: SettingsContainer(
                settingsModel: SettingsModel(
                  icon: Icons.receipt_long_outlined,
                  title: translate("profile.transactions"),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Role-specific section
            if (_isDriver) ...[
              _sectionLabel(translate("profile.driver_section")),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyVehiclesScreen()),
                ),
                child: SettingsContainer(
                  settingsModel: SettingsModel(
                    icon: Icons.directions_car_outlined,
                    title: translate("profile.my_vehicles"),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else ...[
              _buildBecomeDriverBanner(),
              const SizedBox(height: 20),
            ],
            _sectionLabel(translate("profile.settings")),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
              ),
              child: SettingsContainer(
                settingsModel: SettingsModel(
                  icon: Icons.lock_outline_rounded,
                  title: translate("profile.change_password"),
                ),
              ),
            ),
            GestureDetector(
              onTap: _showLanguagePicker,
              child: SettingsContainer(
                settingsModel: SettingsModel(
                  icon: Icons.language_rounded,
                  title: translate("profile.language"),
                ),
                trailingText: _langName,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
              child: SettingsContainer(
                settingsModel: SettingsModel(
                  icon: Icons.notifications_none_rounded,
                  title: translate("profile.notifications"),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(translate("profile.about_us")),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
              child: SettingsContainer(
                settingsModel: SettingsModel(
                  icon: Icons.description_outlined,
                  title: translate("profile.terms"),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsScreen()),
              ),
              child: SettingsContainer(
                settingsModel: SettingsModel(
                  icon: Icons.shield_outlined,
                  title: translate("profile.privacy_security"),
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SupportScreen()),
              ),
              child: SettingsContainer(
                settingsModel: SettingsModel(
                  icon: Icons.headset_mic_outlined,
                  title: translate("profile.contact_us"),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _sectionLabel(translate("profile.other")),
            SettingsContainer(
              settingsModel: SettingsModel(
                icon: Icons.share_outlined,
                title: translate("profile.share"),
              ),
            ),
            GestureDetector(
              onTap: _confirmLogout,
              child: SettingsContainer(
                iconColor: AppTheme.red,
                settingsModel: SettingsModel(
                  icon: Icons.logout_rounded,
                  title: translate("profile.logout"),
                ),
              ),
            ),
            GestureDetector(
              onTap: _confirmDeleteAccount,
              child: SettingsContainer(
                iconColor: AppTheme.red,
                settingsModel: SettingsModel(
                  icon: Icons.delete_forever_rounded,
                  title: translate("profile.delete_account"),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                "ketamiz.com  v1.0.0",
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.gray,
                ),
              ),
            ),
            ],
          ),
          ),
          if (_isDeletingAccount) ...[
            const ModalBarrier(dismissible: false, color: Colors.black54),
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.purple),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Top bar ─────────────────────────────────────────────────────────────
  Widget _buildNotificationBell() {
    return const Padding(
      padding: EdgeInsets.only(right: 12),
      child: NotificationButton(),
    );
  }

  // ── Profile card ────────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 4),
            blurRadius: 24,
            color: AppTheme.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatar(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _myName.isEmpty ? "—" : _myName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _myPhone,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppTheme.gray,
                  ),
                ),
                if (_isDriver) ...[
                  const SizedBox(height: 8),
                  _verifiedBadge(),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _editProfileButton(),
        ],
      ),
    );
  }

  /// Tappable banner nudging the user to fill in the email / father's name
  /// that are no longer collected during registration. Opens the edit screen.
  Widget _buildCompleteProfileBanner() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        ).then((_) {
          if (mounted) _refresh();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.yellow.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.yellow.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: AppTheme.yellow, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text16h500w(title: translate("profile.complete_profile")),
                  const SizedBox(height: 2),
                  Text14h400w(
                    title: translate("profile.complete_profile_msg"),
                    color: AppTheme.dark,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.yellow, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _editProfileButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const EditProfileScreen()),
        ).then((_) {
          if (mounted) _refresh();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.purple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.edit_outlined, size: 14, color: AppTheme.purple),
            const SizedBox(width: 6),
            Text(
              translate("profile.edit_profile"),
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.green.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded, size: 14, color: AppTheme.green),
          const SizedBox(width: 4),
          Text(
            translate("profile.verified_driver"),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppTheme.purple, AppTheme.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _avatarInner(),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: _onEditAvatar,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.light, width: 1.5),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 12, color: AppTheme.purple),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarInner() {
    if (_isUploadingAvatar) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2.5,
        ),
      );
    }
    if (_localAvatarPath.isNotEmpty && File(_localAvatarPath).existsSync()) {
      return Image.file(
        File(_localAvatarPath),
        width: 64,
        height: 64,
        fit: BoxFit.cover,
      );
    }
    if (_myImage.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _myImage,
        width: 64,
        height: 64,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initialsText(),
        errorWidget: (_, __, ___) => _initialsText(),
      );
    }
    return _initialsText();
  }

  Widget _initialsText() {
    return Center(
      child: Text(
        _initials,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  void _onEditAvatar() {
    BottomDialog.showUploadImage(
      context,
      onGallery: () => _pickAndUploadAvatar(ImageSource.gallery),
      onCamera: () => _pickAndUploadAvatar(ImageSource.camera),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final XFile? picked = await ImageHelper.pick(source);
    if (picked == null || !mounted) return;

    // Optimistic in-memory preview while the upload is in flight.
    setState(() {
      _localAvatarPath = picked.path;
      _isUploadingAvatar = true;
    });

    final response = await Repository().fetchUploadProfileImage(picked.path);
    if (!mounted) return;

    if (response.isSuccess) {
      // The server is the source of truth — pull a fresh /me (with the new
      // image URL), switch the avatar over to it and drop the local preview.
      await _syncMeFromServer();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('local_avatar');
      if (!mounted) return;
      setState(() {
        _localAvatarPath = '';
        _myImage = prefs.getString('image') ?? '';
        _isUploadingAvatar = false;
      });
      CustomSnackBar().showSnackBar(
        context,
        translate("profile.image_updated"),
        1,
      );
    } else {
      // Upload failed — revert the optimistic preview.
      setState(() {
        _localAvatarPath = '';
        _isUploadingAvatar = false;
      });
      CenterDialog.showActionFailed(
        context,
        translate("ketamiz.error"),
        translate("profile.image_update_failed"),
      );
    }
  }

  /// Fetches /me from the server and writes it to the local cache so the next
  /// prefs read reflects the latest values (e.g. the newly uploaded image URL).
  Future<void> _syncMeFromServer() async {
    final res = await Repository().fetchMe();
    if (res.isSuccess && res.result is Map<String, dynamic>) {
      final model = GetUserModel.fromJson(res.result);
      if (model.status == 'success') {
        await Repository().cacheSetMe(model.user);
      }
    }
  }

  // ── Balance card ────────────────────────────────────────────────────────
  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.purple, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, 8),
            blurRadius: 20,
            color: AppTheme.purple.withOpacity(0.3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate("profile.my_balance"),
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${Utils.priceFormat(balance)} ${translate("currency")}",
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TopUpScreen()),
              ).then((_) {
                setState(() {
                  blocProfile.fetchMe();
                  getBalance();
                });
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    translate("profile.top_up"),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.purple,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.add_circle_outline_rounded,
                      color: AppTheme.purple, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.gray,
        ),
      ),
    );
  }

  void _confirmLogout() {
    CenterDialog.showConfirmation(
      context,
      translate("profile.logout"),
      translate("profile.logout_confirm"),
      onConfirm: () async {
        Navigator.pop(context); // close the dialog
        // Stop pushes to this device while the JWT is still valid.
        await PushNotificationService.instance.unregisterToken();
        // Best-effort server logout; proceed regardless of result.
        try {
          await Repository().fetchLogout();
        } catch (_) {}
        await wipeSharedPreferences();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      },
    );
  }

  void _confirmDeleteAccount() {
    CenterDialog.showConfirmation(
      context,
      translate("profile.delete_account"),
      translate("profile.delete_account_confirm"),
      onConfirm: () async {
        Navigator.pop(context); // close the confirmation dialog
        setState(() => _isDeletingAccount = true);

        // Remove this device's push token while the JWT is still valid.
        await PushNotificationService.instance.unregisterToken();

        final response = await Repository().fetchDeleteAccount();
        if (!mounted) return;

        if (response.isSuccess) {
          // Account is gone — clear everything (prefs + secure token) and
          // send the user back to the login screen.
          await wipeSharedPreferences();
          await SecureStorage.clearAll();
          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        } else {
          setState(() => _isDeletingAccount = false);
          CenterDialog.showActionFailed(
            context,
            translate("ketamiz.error"),
            response.result is Map && response.result['message'] != null
                ? response.result['message']
                : translate("profile.delete_account_failed"),
          );
        }
      },
    );
  }

  Widget _buildBecomeDriverBanner() {
    if (_verificationStatus == 'pending') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.yellow.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.yellow.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.yellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: AppTheme.yellow, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text16h500w(title: translate("profile.verification_pending")),
                  const SizedBox(height: 2),
                  Text14h400w(
                    title: translate("profile.verification_pending_msg"),
                    color: AppTheme.dark,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_verificationStatus == 'rejected') {
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddDocsScreen()),
        ).then((_) => _refresh()),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.red.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.red.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.error_outline,
                    color: AppTheme.red, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text16h500w(
                        title: translate("profile.verification_rejected")),
                    const SizedBox(height: 2),
                    Text14h400w(
                      title: translate("profile.resubmit_docs"),
                      color: AppTheme.red,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.red, size: 20),
            ],
          ),
        ),
      );
    }

    // status == 'none' — show become driver CTA
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddDocsScreen()),
      ).then((_) => _refresh()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.purple, AppTheme.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              offset: const Offset(0, 4),
              blurRadius: 20,
              color: AppTheme.purple.withOpacity(0.3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.drive_eta_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translate("profile.become_driver"),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    translate("profile.become_driver_subtitle"),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguagePicker() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getString('language') ?? 'uz';

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LanguagePickerSheet(currentCode: current),
    );

    // Rebuild so the locale change is reflected immediately in this screen.
    if (mounted) await _getInfo();
  }

  Future<void> getBalance() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      balance = prefs.getString('balance') ?? "0";
    });
  }

  Future<void> _getInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String firstName = prefs.getString('first_name') ?? '';
    String lastName = prefs.getString('last_name') ?? '';
    final langCode = prefs.getString('language') ?? 'uz';
    final lang = _kLanguages.firstWhere(
      (l) => l['code'] == langCode,
      orElse: () => _kLanguages.first,
    );
    setState(() {
      _myImage = prefs.getString('image') ?? '';
      _localAvatarPath = prefs.getString('local_avatar') ?? '';
      _myName = '$firstName $lastName'.trim();
      _myPhone = prefs.getString('phone') ?? '';
      _myEmail = prefs.getString('email') ?? '';
      _myFatherName = prefs.getString('father_name') ?? '';
      _isDriver = prefs.getString('role') == 'driver';
      _verificationStatus =
          prefs.getString('driving_verification_status') ?? 'none';
      _langName = lang['name']!;
    });
  }

  Future<void> wipeSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet({required this.currentCode});
  final String currentCode;

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late String _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentCode;
  }

  Future<void> _apply() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', _selected);
    // Best-effort sync of language to the backend.
    try {
      Repository().fetchUpdateLanguage(_selected);
    } catch (_) {}
    if (!mounted) return;
    await changeLocale(context, _selected);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text16h500w(title: translate("profile.language")),
          const SizedBox(height: 20),
          ..._kLanguages.map((lang) => GestureDetector(
                onTap: () => setState(() => _selected = lang['code']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _selected == lang['code']
                        ? AppTheme.purple.withOpacity(0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selected == lang['code']
                          ? AppTheme.purple
                          : AppTheme.border,
                      width: _selected == lang['code'] ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        lang['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          lang['name']!,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _selected == lang['code']
                                ? AppTheme.purple
                                : AppTheme.black,
                          ),
                        ),
                      ),
                      if (_selected == lang['code'])
                        const Icon(Icons.check_circle,
                            color: AppTheme.purple, size: 20),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                translate("home.save"),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
