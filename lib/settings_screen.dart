import 'package:flutter/material.dart';

class SettingsScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const SettingsScreen({super.key, required this.onThemeChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isDarkMode = false;
  bool isAIMode = false;

  double bass = 0;
  double mid = 0;
  double treble = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          /// 🌙 Dark Mode
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: isDarkMode,
            onChanged: (value) {
              setState(() => isDarkMode = value);
              widget.onThemeChanged(value);
            },
          ),

          /// 🤖 AI Mode
          SwitchListTile(
            title: const Text("AI Mode"),
            subtitle: const Text("Smart recommendations enabled"),
            value: isAIMode,
            onChanged: (value) {
              setState(() => isAIMode = value);
            },
          ),

          const SizedBox(height: 20),
          const Text("Equalizer", style: TextStyle(fontSize: 18)),

          const SizedBox(height: 10),

          buildSlider("Bass", bass, (v) => setState(() => bass = v)),
          buildSlider("Mid", mid, (v) => setState(() => mid = v)),
          buildSlider("Treble", treble, (v) => setState(() => treble = v)),
        ],
      ),
    );
  }

  Widget buildSlider(String label, double value, Function(double) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("$label (${value.toInt()})"),
        Slider(
          value: value,
          min: -10,
          max: 10,
          divisions: 20,
          label: value.toInt().toString(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}