import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:ciyue/src/generated/i18n/app_localizations.dart';

class TermsOfService extends StatelessWidget {
  const TermsOfService({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.termsOfService),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: SelectionArea(child: GptMarkdown('''
              # Terms of Service

              ## Acceptance of Terms
              
              By using Ciyue, you agree to these Terms of Service.
              
              ## Use of Third-Party Services
              
              Ciyue is a software that integrates with third-party services (e.g., OpenAI, Google Gemini) when you configure certain options. When you use these third-party services within Ciyue, you must comply with their respective Terms of Service and privacy policies.
              
              ## User Responsibility
              
              You are solely responsible for your use of Ciyue, including any consequences arising from such use. We, the maintainers and contributors of Ciyue, are not liable for any issues, damages, or obligations related to your use of Ciyue or its integrated third-party services.
              
              ## Modification of Terms
              
              We reserve the right to update these Terms of Service at any time. Continued use of Ciyue after changes constitutes your acceptance of the updated terms.
              ''')),
              ),
            ),
          ),
        ));
  }
}
