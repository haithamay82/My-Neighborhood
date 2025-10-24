import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/phone_validation.dart';

class PhoneInputWidget extends StatefulWidget {
  final String? initialPrefix;
  final String? initialNumber;
  final Function(String prefix, String number)? onChanged;
  final String? Function(String?)? validator;
  final bool isRequired;

  const PhoneInputWidget({
    super.key,
    this.initialPrefix,
    this.initialNumber,
    this.onChanged,
    this.validator,
    this.isRequired = false,
  });

  @override
  State<PhoneInputWidget> createState() => _PhoneInputWidgetState();
}

class _PhoneInputWidgetState extends State<PhoneInputWidget> {
  String _selectedPrefix = '';
  final TextEditingController _numberController = TextEditingController();
  final FocusNode _numberFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _selectedPrefix = widget.initialPrefix ?? '';
    _numberController.text = widget.initialNumber ?? '';
    
    // עדכון השדה הימני עם המספר המלא אם יש קידומת ומספר
    if (_selectedPrefix.isNotEmpty && _numberController.text.isNotEmpty) {
      // בדיקה אם המספר כבר מכיל את הקידומת
      if (!_numberController.text.contains('$_selectedPrefix-')) {
        final fullNumber = '$_selectedPrefix-${_numberController.text}';
        // שימוש ב-WidgetsBinding.instance.addPostFrameCallback כדי למנוע setState במהלך build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _numberController.text = fullNumber;
          }
        });
      }
    }
  }

  @override
  void didUpdateWidget(PhoneInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPrefix != oldWidget.initialPrefix) {
      setState(() {
        _selectedPrefix = widget.initialPrefix ?? '';
      });
    }
    if (widget.initialNumber != oldWidget.initialNumber) {
      // שימוש ב-WidgetsBinding.instance.addPostFrameCallback כדי למנוע setState במהלך build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _numberController.text = widget.initialNumber ?? '';
        }
      });
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _numberFocusNode.dispose();
    super.dispose();
  }

  void _onPrefixChanged(String? newPrefix) {
    if (newPrefix != null) {
      setState(() {
        _selectedPrefix = newPrefix;
      });
      
      // עדכון השדה הימני עם המספר המלא רק אם יש מספר
      if (_numberController.text.isNotEmpty && !_numberController.text.contains('$_selectedPrefix-')) {
        final currentNumber = _numberController.text;
        final fullNumber = '$_selectedPrefix-$currentNumber';
        // שימוש ב-WidgetsBinding.instance.addPostFrameCallback כדי למנוע setState במהלך build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _numberController.text = fullNumber;
            _numberController.selection = TextSelection.fromPosition(
              TextPosition(offset: fullNumber.length),
            );
          }
        });
      }
      
      _notifyChange();
    }
  }

  void _onNumberChanged(String value) {
    // בדיקה אם המספר כבר מכיל את הקידומת
    if (value.contains('$_selectedPrefix-')) {
      // המספר כבר מכיל את הקידומת, לא צריך לעשות כלום
      debugPrint('🔍 PhoneInputWidget: Number already contains prefix: $value');
      _notifyChange();
      return;
    }
    
    // הגבלת אורך המספר (רק החלק ללא הקידומת)
    if (value.length > PhoneValidation.israeliPhoneLength) {
      final cleanNumber = value.substring(0, PhoneValidation.israeliPhoneLength);
      // שימוש ב-WidgetsBinding.instance.addPostFrameCallback כדי למנוע setState במהלך build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _numberController.text = cleanNumber;
          _numberController.selection = TextSelection.fromPosition(
            TextPosition(offset: cleanNumber.length),
          );
        }
      });
    }
    
    debugPrint('🔍 PhoneInputWidget: Number changed to: $value, prefix: $_selectedPrefix');
    _notifyChange();
  }

  void _notifyChange() {
    if (widget.onChanged != null) {
      widget.onChanged!(_selectedPrefix, _numberController.text);
    }
  }

  String? _validatePhone(String? value) {
    if (widget.isRequired && (_selectedPrefix.isEmpty || _numberController.text.isEmpty)) {
      return 'מספר טלפון נדרש';
    }
    
    if (_selectedPrefix.isNotEmpty && _numberController.text.isNotEmpty) {
      String fullNumber = '$_selectedPrefix${_numberController.text}';
      if (!PhoneValidation.isValidIsraeliPhone(fullNumber)) {
        return 'מספר טלפון לא תקין';
      }
    }
    
    return widget.validator?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final groupedPrefixes = PhoneValidation.getGroupedPrefixes();
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // שדה מספר טלפון מלא - מוצמד לצד שמאל
          Expanded(
            flex: 3,
            child: TextFormField(
            controller: _numberController,
            focusNode: _numberFocusNode,
            decoration: InputDecoration(
              labelText: 'מספר טלפון',
              border: const OutlineInputBorder(),
              hintText: _selectedPrefix.isNotEmpty 
                  ? '0' * PhoneValidation.israeliPhoneLength 
                  : 'בחר קידומת תחילה',
              counterText: _selectedPrefix.isNotEmpty 
                  ? '${_numberController.text.length}/${PhoneValidation.israeliPhoneLength}'
                  : '',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(PhoneValidation.israeliPhoneLength),
            ],
            onChanged: _onNumberChanged,
            validator: _validatePhone,
            enabled: _selectedPrefix.isNotEmpty,
            textAlign: TextAlign.left, // הצמדה לצד שמאל (LTR)
            ),
          ),
          const SizedBox(width: 8),
          
          // בחירת קידומת - שדה קטן (תמיד מצד ימין)
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
            value: _selectedPrefix.isEmpty ? null : _selectedPrefix,
            decoration: const InputDecoration(
              labelText: 'קידומת',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            hint: const Text('בחר'),
            items: groupedPrefixes.entries.expand((group) {
              return [
                // כותרת קבוצה
                DropdownMenuItem<String>(
                  value: '__header__${group.key}',
                  enabled: false,
                  child: Text(
                    group.key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                // קידומות בקבוצה
                ...group.value.map((prefix) => DropdownMenuItem<String>(
                  value: prefix,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(prefix),
                  ),
                )),
              ];
            }).toList(),
            onChanged: _onPrefixChanged,
            validator: (value) {
              if (widget.isRequired && (value == null || value.isEmpty)) {
                return 'בחר קידומת';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}
