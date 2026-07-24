import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app/app_navigator.dart';
import 'app/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'data/services/notification_service.dart';
import 'firebase_options.dart';
import 'screens/add_transaction/add_transaction_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/ai_insights/ai_insights_screen.dart';
import 'screens/budget/budget_management_screen.dart';
import 'screens/currency_converter/currency_converter_screen.dart';
import 'screens/edit_transaction/edit_transaction_screen.dart';
import 'screens/documents/documents_screen.dart';
import 'screens/bug_report/bug_report_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/statistics/statistics_screen.dart';
import 'screens/transaction_detail/transaction_detail_screen.dart';
import 'screens/transactions/transactions_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.instance.initialize();
  runApp(const SmartExpenseManagerApp());
}

class SmartExpenseManagerApp extends StatelessWidget {
  const SmartExpenseManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Smart Expense Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          initialRoute: AppRoutes.splash,
          routes: {
            AppRoutes.splash: (context) => const SplashScreen(),
            AppRoutes.login: (context) => const LoginScreen(),
            AppRoutes.onboarding: (context) => const OnboardingScreen(),
            AppRoutes.home: (context) => const HomeScreen(),
            AppRoutes.addTransaction: (context) => const AddTransactionScreen(),
            AppRoutes.editTransaction: (context) =>
                const EditTransactionScreen(),
            AppRoutes.currencyConverter: (context) =>
                const CurrencyConverterScreen(),
            AppRoutes.budgetManagement: (context) =>
                const BudgetManagementScreen(),
            AppRoutes.transactions: (context) => const TransactionsScreen(),
            AppRoutes.transactionDetail: (context) =>
                const TransactionDetailScreen(),
            AppRoutes.notifications: (context) => const NotificationsScreen(),
            AppRoutes.statistics: (context) => const StatisticsScreen(),
            AppRoutes.profile: (context) => const ProfileScreen(),
            AppRoutes.editProfile: (context) => const EditProfileScreen(),
            AppRoutes.settings: (context) => const SettingsScreen(),
            AppRoutes.aiInsights: (context) => const AiInsightsScreen(),
            AppRoutes.documents: (context) => const DocumentsScreen(),
            AppRoutes.bugReport: (context) => const BugReportScreen(),
            AppRoutes.register: (context) => const RegisterScreen(),
            AppRoutes.forgotPassword: (context) => const ForgotPasswordScreen(),
          },
        );
      },
    );
  }
}
