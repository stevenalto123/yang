import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_theme.dart';
import '../utils/pwa_bridge.dart';

class SurvivalToolsScreen extends StatefulWidget {
  const SurvivalToolsScreen({super.key});

  @override
  State<SurvivalToolsScreen> createState() => _SurvivalToolsScreenState();
}

class _SurvivalToolsScreenState extends State<SurvivalToolsScreen> {
  bool _whistleOn = false;
  bool _steadyLightOn = false;
  bool _strobeOn = false;
  bool _strobeLit = false;
  Timer? _strobeTimer;

  // Morse SOS pattern: ... --- ...
  static const List<int> _sosDurationsMs = [
    180, 180, 180, 180, 180, 360, // S (...)
    520, 180, 520, 180, 520, 360, // O (---)
    180, 180, 180, 180, 180, 900, // S (...) + pause
  ];
  int _sosIndex = 0;

  @override
  void dispose() {
    _strobeTimer?.cancel();
    stopEmergencyWhistle();
    super.dispose();
  }

  void _toggleWhistle() {
    if (_whistleOn) {
      stopEmergencyWhistle();
      setState(() => _whistleOn = false);
      return;
    }
    final started = startEmergencyWhistle();
    if (started) {
      setState(() => _whistleOn = true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Audio whistle requires an active web browser speaker. Use SOS Light or blow a physical whistle.',
          ),
        ),
      );
    }
  }

  void _toggleSteadyLight() {
    _strobeTimer?.cancel();
    setState(() {
      _strobeOn = false;
      _strobeLit = false;
      _steadyLightOn = !_steadyLightOn;
    });
  }

  void _toggleStrobe() {
    _strobeTimer?.cancel();
    if (_strobeOn) {
      setState(() {
        _strobeOn = false;
        _strobeLit = false;
      });
      return;
    }
    setState(() {
      _steadyLightOn = false;
      _strobeOn = true;
      _strobeLit = true;
      _sosIndex = 0;
    });
    _scheduleNextSosTick();
  }

  void _scheduleNextSosTick() {
    if (!_strobeOn || !mounted) return;
    final ms = _sosDurationsMs[_sosIndex % _sosDurationsMs.length];
    _strobeTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted || !_strobeOn) return;
      setState(() {
        _sosIndex = (_sosIndex + 1) % _sosDurationsMs.length;
        _strobeLit = _sosIndex.isEven;
      });
      _scheduleNextSosTick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFil = context.watch<SettingsProvider>().isFilipino;
    final isFullScreenLight = _steadyLightOn || _strobeOn;
    final isLit = _steadyLightOn || (_strobeOn && _strobeLit);

    if (isFullScreenLight) {
      return Scaffold(
        backgroundColor: isLit ? Colors.white : Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _strobeTimer?.cancel();
            setState(() {
              _steadyLightOn = false;
              _strobeOn = false;
              _strobeLit = false;
            });
          },
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _strobeOn ? Icons.sos_rounded : Icons.flashlight_on_rounded,
                  size: 64,
                  color: isLit ? Colors.black26 : Colors.white24,
                ),
                const SizedBox(height: 16),
                Text(
                  _strobeOn
                      ? (isFil
                          ? 'SOS Strobe Aktibo • I-tap kahit saan para ihinto'
                          : 'SOS Morse Strobe Active • Tap anywhere to stop')
                      : (isFil
                          ? 'I-tap kahit saan para patayin ang ilaw'
                          : 'Tap anywhere to turn off screen light'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isLit ? Colors.black45 : Colors.white54,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        title: Text(
          isFil ? 'Offline Survival Tools' : 'Offline Survival Tools',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.offline_bolt_rounded,
                      color: Color(0xFF4ADE80),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isFil
                            ? 'Gumagana 100% offline kahit walang signal o kuryente. Nakakatulong sa rescuers na matagpuan ka.'
                            : 'Works 100% offline during brownouts or earthquakes to help rescuers locate you.',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 1. Rescue Whistle (3.1 kHz pulsing)
              _buildToolButton(
                icon: _whistleOn
                    ? Icons.volume_up_rounded
                    : Icons.campaign_rounded,
                title: _whistleOn
                    ? (isFil ? 'Patayin ang Rescue Whistle' : 'Stop Rescue Whistle')
                    : (isFil ? 'Patunugin ang Rescue Whistle' : 'Sound Emergency Whistle'),
                subtitle: isFil
                    ? '3.1 kHz malakas na tunog para marinig ng rescuers'
                    : 'Loud 3.1 kHz pulsing rescue tone to alert responders',
                active: _whistleOn,
                activeColor: AppTheme.dangerRed,
                onTap: _toggleWhistle,
              ),
              const SizedBox(height: 14),

              // 2. Morse SOS Screen Strobe
              _buildToolButton(
                icon: Icons.sos_rounded,
                title: _strobeOn
                    ? (isFil ? 'Patayin ang SOS Strobe' : 'Stop SOS Strobe')
                    : (isFil ? 'SOS Morse Light Strobe' : 'SOS Morse Screen Strobe'),
                subtitle: isFil
                    ? 'Kumikislap na (... --- ...) SOS signal sa screen'
                    : 'Flashes international Morse (... --- ...) SOS signal',
                active: _strobeOn,
                activeColor: AppTheme.warningAmber,
                onTap: _toggleStrobe,
              ),
              const SizedBox(height: 14),

              // 3. Steady Bright Screen Light (Brownout)
              _buildToolButton(
                icon: Icons.flashlight_on_rounded,
                title: isFil
                    ? 'Maliwanag na Screen (Brownout)'
                    : 'Bright Screen Light (Brownout)',
                subtitle: isFil
                    ? 'Puting screen na pwedeng gamiting emergency light'
                    : 'Full-screen bright white emergency illumination',
                active: _steadyLightOn,
                activeColor: AppTheme.primaryAccent,
                onTap: _toggleSteadyLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: active ? activeColor : const Color(0xFF162238),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: active ? Colors.white60 : Colors.white12,
              width: active ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(active ? 36 : 16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                active ? Icons.stop_circle_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
