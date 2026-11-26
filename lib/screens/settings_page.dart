import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _ip;
  late final TextEditingController _port;
  late final TextEditingController _listenPort;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _ip = TextEditingController(text: state.settings.targetIp);
    _port = TextEditingController(text: state.settings.targetPort.toString());
    _listenPort =
        TextEditingController(text: state.settings.listenPort.toString());
    state.refreshLocalIps();
  }

  @override
  void dispose() {
    _ip.dispose();
    _port.dispose();
    _listenPort.dispose();
    super.dispose();
  }

  void _apply() {
    final state = context.read<AppState>();
    final port = int.tryParse(_port.text);
    final listenPort = int.tryParse(_listenPort.text);
    state.updateSettings(
      targetIp: _ip.text.trim(),
      targetPort: (port != null && port > 0 && port < 65536) ? port : null,
      listenPort: (listenPort != null && listenPort > 0 && listenPort < 65536)
          ? listenPort
          : null,
    );
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Settings applied'),
          duration: Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Send OSC to', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _ip,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Server IP address',
              hintText: '192.168.1.100',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.dns_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _port,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Server port',
              hintText: '8000',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 24),
          Text('Receive OSC on this device',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _listenPort,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Listen port',
              hintText: '9000',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.hearing),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi, size: 20),
                      const SizedBox(width: 8),
                      Text('This device',
                          style: Theme.of(context).textTheme.titleSmall),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        tooltip: 'Refresh IP',
                        onPressed: state.refreshLocalIps,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (state.localIps.isEmpty)
                    const Text('No network connection detected')
                  else
                    for (final ip in state.localIps)
                      SelectableText(
                        '$ip : ${state.settings.listenPort}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                  const SizedBox(height: 4),
                  Text(
                    'Point your OSC software at this address.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (state.oscError != null) ...[
                    const SizedBox(height: 8),
                    Text(state.oscError!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check),
            label: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
