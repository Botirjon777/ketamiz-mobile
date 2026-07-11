import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_translate/flutter_translate.dart';
import 'package:latlong2/latlong.dart';

import '../../../model/api/parcel_model.dart';
import '../../../model/api/trip_list_model.dart';
import '../../../resources/repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/utils.dart';
import '../../dialogs/center_dialog.dart';
import '../../dialogs/snack_bar.dart';
import '../../widgets/containers/leading_back.dart';
import '../../widgets/texts/text_16h_500w.dart';
import '../new_ketamiz/map_select_screen.dart';
import 'parcel_detail_screen.dart';

/// Client form for sending a parcel on a trip that accepts parcels. Validates
/// against the trip's parcel config (weight/dimension limits, allowed types)
/// locally and surfaces the backend's localized message on 422.
class SendParcelScreen extends StatefulWidget {
  const SendParcelScreen({super.key, required this.trip});

  final TripListModel trip;

  @override
  State<SendParcelScreen> createState() => _SendParcelScreenState();
}

class _SendParcelScreenState extends State<SendParcelScreen> {
  final Repository _repository = Repository();

  final _weightController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  ParcelType? _selectedType;
  LatLng? _pickupLocation;
  bool _submitting = false;

  ParcelInfo get _parcel => widget.trip.parcel!;

  @override
  void initState() {
    super.initState();
    if (_parcel.types.length == 1) _selectedType = _parcel.types.first;
    _weightController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _weightController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  double get _weight => double.tryParse(_weightController.text.trim()) ?? 0;

  double get _totalPrice => _weight * _parcel.pricePerKg;

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      CenterDialog.showActionFailed(
          context, translate("parcel.title"), error);
      return;
    }

    setState(() => _submitting = true);
    final response = await _repository.fetchCreateParcelBooking(
      tripId: widget.trip.id,
      parcelTypeId: _selectedType!.id,
      weight: _weight,
      receiverPhone: _phoneController.text.trim(),
      latitude: _pickupLocation!.latitude.toString(),
      longitude: _pickupLocation!.longitude.toString(),
      length: _intOrNull(_lengthController.text),
      width: _intOrNull(_widthController.text),
      height: _intOrNull(_heightController.text),
      description: _descriptionController.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (response.isSuccess) {
      final booking = ParcelBooking.fromResult(response.result);
      CustomSnackBar()
          .showSnackBar(context, translate("parcel.sent_success"), 1);
      if (booking != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ParcelDetailScreen(bookingId: booking.id),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } else {
      // Backend returns a localized, user-facing message (422 business rules).
      final msg = (response.result is Map
              ? response.result['message']?.toString()
              : null) ??
          translate("auth.something_went_wrong");
      CenterDialog.showActionFailed(context, translate("parcel.title"), msg);
    }
  }

  /// Local validation mirroring the backend rules so the user gets instant
  /// feedback; the backend re-checks and is the source of truth.
  String? _validate() {
    if (_selectedType == null) return translate("parcel.select_type_error");
    if (_weight < 0.1) return translate("parcel.weight_min_error");
    if (_weight > _parcel.availableWeight) {
      return translate("parcel.weight_available_error",
          args: {"weight": Utils.weightFormat(_parcel.availableWeight)});
    }
    final l = _intOrNull(_lengthController.text);
    final w = _intOrNull(_widthController.text);
    final h = _intOrNull(_heightController.text);
    if (_parcel.maxLength > 0 && l != null && l > _parcel.maxLength) {
      return translate("parcel.size_error");
    }
    if (_parcel.maxWidth > 0 && w != null && w > _parcel.maxWidth) {
      return translate("parcel.size_error");
    }
    if (_parcel.maxHeight > 0 && h != null && h > _parcel.maxHeight) {
      return translate("parcel.size_error");
    }
    if (_phoneController.text.trim().isEmpty) {
      return translate("parcel.receiver_phone_error");
    }
    if (_pickupLocation == null) {
      return translate("home.set_pickup_location");
    }
    return null;
  }

  int? _intOrNull(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  Future<void> _pickPickupLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => MapSelectScreen(
          place: widget.trip.fromWhere,
          onSelected: (_) {},
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _pickupLocation = picked);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const LeadingBack(),
        title: Text16h500w(title: translate("parcel.send_parcel")),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  _buildLimitsCard(),
                  const SizedBox(height: 20),
                  _label(translate("parcel.parcel_type")),
                  const SizedBox(height: 8),
                  _buildTypeSelector(),
                  const SizedBox(height: 18),
                  _label(translate("parcel.weight_kg")),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _weightController,
                    hint: translate("parcel.weight_hint"),
                    icon: Icons.scale_outlined,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    formatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _label(translate("parcel.dimensions_optional")),
                  const SizedBox(height: 8),
                  _buildDimensionsRow(),
                  const SizedBox(height: 18),
                  _label(translate("parcel.receiver_phone")),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _phoneController,
                    hint: "+998 90 123 45 67",
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),
                  _label(translate("home.pickup_location")),
                  const SizedBox(height: 8),
                  _buildPickupLocationField(),
                  const SizedBox(height: 18),
                  _label(translate("parcel.description_optional")),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _descriptionController,
                    hint: translate("parcel.description_hint"),
                    icon: Icons.notes_outlined,
                    maxLength: 150,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitsCard() {
    final p = _parcel;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.purple.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _limitRow(translate("parcel.available_weight"),
              "${Utils.weightFormat(p.availableWeight)} ${translate("parcel.kg")}"),
          const SizedBox(height: 8),
          _limitRow(translate("parcel.price_per_kg"),
              "${Utils.priceFromNum(p.pricePerKg)} ${translate("currency")}"),
          if (p.hasDimensionLimits) ...[
            const SizedBox(height: 8),
            _limitRow(
              translate("parcel.max_size"),
              "${p.maxLength}×${p.maxWidth}×${p.maxHeight} ${translate("parcel.cm")}",
            ),
          ],
        ],
      ),
    );
  }

  Widget _limitRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.gray,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.black,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppTheme.black,
      ),
    );
  }

  Widget _buildTypeSelector() {
    return GestureDetector(
      onTap: _pickType,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.category_outlined,
                color: AppTheme.purple, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedType?.name ?? translate("parcel.select_type"),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: _selectedType == null
                      ? AppTheme.gray
                      : AppTheme.black,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.gray, size: 20),
          ],
        ),
      ),
    );
  }

  void _pickType() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text16h500w(title: translate("parcel.select_type")),
              const SizedBox(height: 12),
              ..._parcel.types.map((t) {
                final selected = _selectedType?.id == t.id;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedType = t);
                    Navigator.pop(ctx);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.purple.withValues(alpha: 0.08)
                          : AppTheme.light,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppTheme.purple : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.name,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? AppTheme.purple
                                  : AppTheme.black,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check_circle,
                              color: AppTheme.purple, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPickupLocationField() {
    return GestureDetector(
      onTap: _pickPickupLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _pickupLocation == null ? AppTheme.border : AppTheme.purple,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                color: AppTheme.purple, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _pickupLocation == null
                    ? translate("home.pickup_choose_on_map")
                    : translate("home.pickup_location_set"),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color:
                      _pickupLocation == null ? AppTheme.gray : AppTheme.black,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppTheme.gray, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildTextField(
            controller: _lengthController,
            hint: translate("parcel.length"),
            icon: Icons.straighten_outlined,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            dense: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTextField(
            controller: _widthController,
            hint: translate("parcel.width"),
            icon: Icons.straighten_outlined,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            dense: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildTextField(
            controller: _heightController,
            hint: translate("parcel.height"),
            icon: Icons.straighten_outlined,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            dense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter> formatters = const [],
    int maxLines = 1,
    int? maxLength,
    bool dense = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      maxLines: maxLines,
      maxLength: maxLength,
      cursorColor: AppTheme.purple,
      style: const TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontSize: 14,
        color: AppTheme.black,
      ),
      decoration: InputDecoration(
        hintText: hint,
        counterText: "",
        hintStyle: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: dense ? 13 : 14,
          color: AppTheme.gray,
        ),
        prefixIcon: Icon(icon, color: AppTheme.purple, size: 20),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 14, vertical: dense ? 12 : 16),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.purple),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: 14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -4),
            blurRadius: 16,
            color: AppTheme.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                translate("parcel.total_price"),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.gray,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "${Utils.priceFromNum(_totalPrice)} ${translate("currency")}",
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.black,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _submitting ? null : _submit,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.purple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          translate("parcel.send"),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
