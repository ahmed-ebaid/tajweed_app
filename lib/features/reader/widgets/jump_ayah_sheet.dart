import 'package:flutter/material.dart';

class JumpAyahSheet extends StatefulWidget {
  final int maxAyah;
  final void Function(int) onJump;

  const JumpAyahSheet({
    super.key,
    required this.maxAyah,
    required this.onJump,
  });

  @override
  State<JumpAyahSheet> createState() => _JumpAyahSheetState();
}

class _JumpAyahSheetState extends State<JumpAyahSheet> {
  late TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleJump() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Please enter an ayah number');
      return;
    }

    final ayahNumber = int.tryParse(input);
    if (ayahNumber == null) {
      setState(() => _error = 'Please enter a valid number');
      return;
    }

    if (ayahNumber < 1 || ayahNumber > widget.maxAyah) {
      setState(() => _error = 'Ayah must be between 1 and ${widget.maxAyah}');
      return;
    }

    widget.onJump(ayahNumber);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      maxChildSize: 0.5,
      minChildSize: 0.3,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: controller,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jump to Ayah',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter ayah number (1-${widget.maxAyah})',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        errorText: _error,
                        suffixIcon: _controller.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _error = null);
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() => _error = null),
                      onSubmitted: (_) => _handleJump(),
                      autofocus: true,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D9E75),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _handleJump,
                        child: const Text('Jump'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
