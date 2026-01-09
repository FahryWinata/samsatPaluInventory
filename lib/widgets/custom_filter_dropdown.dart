import 'package:flutter/material.dart';

class CustomFilterDropdown<T> extends StatefulWidget {
  final String label;
  final List<T> items;
  final List<T> selectedItems;
  final String Function(T) itemLabelBuilder;
  final Function(List<T>) onChanged;
  final String? hint;

  const CustomFilterDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.selectedItems,
    required this.itemLabelBuilder,
    required this.onChanged,
    this.hint,
  });

  @override
  State<CustomFilterDropdown<T>> createState() =>
      _CustomFilterDropdownState<T>();
}

class _CustomFilterDropdownState<T> extends State<CustomFilterDropdown<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    // Position calculated in OverlayEntry below

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Close when clicking outside
          GestureDetector(
            onTap: _closeDropdown,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            width: 250, // Fixed width for the dropdown menu
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0.0, size.height + 5.0),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              widget.hint ?? 'Select Options',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                            if (widget.selectedItems.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  widget.onChanged([]);
                                  // Rebuild overlay to show cleared state
                                  _overlayEntry?.markNeedsBuild();
                                },
                                child: Text(
                                  'Clear',
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // List
                      Flexible(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: widget.items.length,
                          itemBuilder: (context, index) {
                            final item = widget.items[index];
                            final isSelected = widget.selectedItems.contains(
                              item,
                            );

                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(widget.itemLabelBuilder(item)),
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              activeColor: Theme.of(context).primaryColor,
                              onChanged: (bool? checked) {
                                final newSelection = List<T>.from(
                                  widget.selectedItems,
                                );
                                if (checked == true) {
                                  newSelection.add(item);
                                } else {
                                  newSelection.remove(item);
                                }
                                widget.onChanged(newSelection);
                                // The parent will rebuild this widget, but we need to trigger
                                // rebuild of the overlay content too.
                                // In this implementation, the parent state update should
                                // trigger this widget to update, which should update the overlay.
                                // However, OverlayEntry doesn't automatically rebuild when parent does.
                                _overlayEntry?.markNeedsBuild();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didUpdateWidget(CustomFilterDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _overlayEntry?.markNeedsBuild();
      });
    }
  }

  @override
  void dispose() {
    if (_isOpen) {
      _overlayEntry?.remove();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Label logic
    String displayLabel = widget.label;
    if (widget.selectedItems.isNotEmpty) {
      if (widget.selectedItems.length == 1) {
        displayLabel = widget.itemLabelBuilder(widget.selectedItems.first);
      } else {
        displayLabel = '${widget.label} (${widget.selectedItems.length})';
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleDropdown,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isOpen
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade300,
              width: _isOpen ? 1.5 : 1,
            ),
            boxShadow: [
              if (!_isOpen)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                displayLabel,
                style: TextStyle(
                  color: widget.selectedItems.isNotEmpty
                      ? Colors.black87
                      : Colors.grey.shade700,
                  fontWeight: widget.selectedItems.isNotEmpty
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18,
                color: Colors.grey.shade600,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
