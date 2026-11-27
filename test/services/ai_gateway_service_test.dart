import 'package:flutter_test/flutter_test.dart';
import 'package:ssh_app/models/ai_provider.dart';
import 'package:ssh_app/services/ai_gateway_service.dart';

void main() {
  group('AiGatewayService NonFreeNet gate', () {
    test('empty API key fails before any network call', () async {
      await expectLater(
        AiGatewayService.generateCommand(
          provider: AiProvider.opencodeZen,
          apiKey: '',
          model: AiGatewayService.defaultOpencodeModel,
          userPrompt: 'list files',
        ),
        throwsA(
          isA<AiGatewayException>().having(
            (AiGatewayException e) => e.message,
            'message',
            contains('API key is required'),
          ),
        ),
      );
    });

    test('blank prompt fails before any network call', () async {
      await expectLater(
        AiGatewayService.generateCommand(
          provider: AiProvider.kiloGateway,
          apiKey: 'not-a-real-key',
          model: AiGatewayService.defaultKiloModel,
          userPrompt: '   ',
        ),
        throwsA(
          isA<AiGatewayException>().having(
            (AiGatewayException e) => e.message,
            'message',
            contains('Describe the command'),
          ),
        ),
      );
    });

    test('base URLs match NonFreeNet disclosure', () {
      expect(
        AiGatewayService.baseUrlFor(AiProvider.opencodeZen),
        'https://opencode.ai/zen/v1',
      );
      expect(
        AiGatewayService.baseUrlFor(AiProvider.kiloGateway),
        'https://api.kilo.ai/api/gateway',
      );
    });

    test('default test build keeps cloud AI enabled', () {
      // Izzy builds pass --dart-define=CLOUD_AI=false; unit tests use default.
      expect(
        () => AiGatewayService.fetchModels(
          provider: AiProvider.opencodeZen,
          apiKey: '',
        ),
        throwsA(
          isA<AiGatewayException>().having(
            (AiGatewayException e) => e.message,
            'message',
            contains('API key is required'),
          ),
        ),
      );
    });
  });
}
