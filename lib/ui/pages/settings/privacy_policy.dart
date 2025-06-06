import "package:flutter/material.dart";
import "package:gpt_markdown/gpt_markdown.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.privacyPolicy),
          leading: BackButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: SelectionArea(
                child: GptMarkdown(
                  '''
            # Privacy Policy

            ## Definition
            
            In this agreement, "we" defined as the maintainers and contributors of Ciyue.
            
            ## Our Data Practices
            
            Ciyue is an open-source software. We do not provide any services that collect, store, or process your personal data through Ciyue itself.
            
            ## Ciyue's Functionality
            
            Ciyue operates as a software that integrates with third-party services (e.g., OpenAI, Google Gemini) to deliver its functionality. Ciyue does not connect to any third-party services by default; it only does so when users configure certain options.
            
            ## Third-Party Policies
            
            By using any third-party services Ciyue connects to, you agree to the respective privacy policies and terms of service of those providers. We encourage you to review these policies to understand how your data may be handled.
            
            ## Disclaimer
            
            We are not responsible for the data practices of these third-party services.
            ''',
                ),
              ),
            ),
          ),
        )));
  }
}
