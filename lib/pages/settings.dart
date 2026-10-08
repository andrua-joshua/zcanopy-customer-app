import 'package:flutter/material.dart';
import 'package:zcanopy/pages/terms.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zcanopy/theme/theme_controller.dart';
import 'package:zcanopy/utils/theme_extensions.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool newForYou = true;
  bool accountActivity = true;
  bool opportunity = false;
  final database = Hive.box('myStore');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 10),

          _buildSectionHeader(Icons.palette_outlined, "Appearance"),
          _buildDividerList([
            ListTile(
              title: const Text("Theme", style: TextStyle(fontSize: 15)),
              subtitle: Text(_themeModeLabel(themeController.themeMode)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showThemePicker,
            ),
          ]),

          const SizedBox(height: 20),

          _buildSectionHeader(Icons.person_outline, "Account"),
          _buildDividerList([
            _buildNavigationItem("Terms of agreement", onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TermsOfServicePage()),
              );
            }),
          ]),

          const SizedBox(height: 20),

       /*   _buildSectionHeader(Icons.notifications_outlined, "Notifications"),
          _buildDividerList([
            _buildSwitchItem("New for you", newForYou, (val) {
              setState(() => newForYou = val);
              database.put('recieveNewPropertiesNotification', true);
            }),
            _buildSwitchItem("Account activity", accountActivity, (val) {
              setState(() => accountActivity = val);
              database.put('recieveAccountActivityNotification', true);
            }),
            _buildSwitchItem("Opportunity", opportunity, (val) {
              setState(() => opportunity = val);
              database.put('recieveOpportunityNotification', true);
            }),
          ]),*/

          const SizedBox(height: 40),

          Center(
       /*     child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.appOnSurface.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              ),
              onPressed: () async {
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const OnBoardingScreen()));

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("You were succseffully logged out")),
                );

                final payload = {
                  "userID": database.get('userID'),
                  "sessionID": database.get('sessionID')
                };

                final response = await postData(payload);

                if (response.success) {
                  database.delete('sessionID');

                  Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => const OnBoardingScreen()));

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("You were succseffully logged out")),
                  );
                }
              },
              child: const Text(
                "SIGN OUT",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),*/
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return "Light";
      case ThemeMode.dark:
        return "Dark";
      case ThemeMode.system:
        return "System default";
    }
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    "Choose theme",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                _themeOption(
                  icon: Icons.brightness_auto,
                  label: "System default",
                  mode: ThemeMode.system,
                ),
                _themeOption(
                  icon: Icons.light_mode_outlined,
                  label: "Light",
                  mode: ThemeMode.light,
                ),
                _themeOption(
                  icon: Icons.dark_mode_outlined,
                  label: "Dark",
                  mode: ThemeMode.dark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themeOption({
    required IconData icon,
    required String label,
    required ThemeMode mode,
  }) {
    final selected = themeController.themeMode == mode;
    return ListTile(
      leading: Icon(icon, color: context.appPrimary),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle, color: context.appPrimary)
          : null,
      onTap: () async {
        await themeController.setThemeMode(mode);
        if (mounted) setState(() {});
        if (context.mounted) Navigator.pop(context);
      },
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.appPrimary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: context.appOnSurface.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem(String title, {VoidCallback? onTap}) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 16, color: context.appOnSurface.withOpacity(0.45)),
      onTap: onTap,
    );
  }

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text(title, style: const TextStyle(fontSize: 15)),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildDividerList(List<Widget> children) {
    return Column(
      children: List.generate(children.length * 2 - 1, (i) {
        if (i.isOdd) {
          return const Divider(height: 1, indent: 16, endIndent: 16);
        }
        return children[i ~/ 2];
      }),
    );
  }
}
