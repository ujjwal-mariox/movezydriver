import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:movezy_driver_app/Screens/ChatScreen/chat_service.dart';

Map<String, dynamic> message(int id) => {
  '_id': id.toString(),
  'bookingId': 'booking',
  'senderId': 'customer',
  'senderType': 'USER',
  'messageType': 'TEXT',
  'message': 'Message $id',
  'createdAt': DateTime.utc(
    2026,
    10,
    6,
  ).add(Duration(seconds: id)).toIso8601String(),
};

http.Response history(List<Map<String, dynamic>> messages, {int pages = 1}) =>
    http.Response(
      jsonEncode({
        'data': {
          'messages': messages,
          'pagination': {'pages': pages},
        },
      }),
      200,
    );

class TestSocket implements io.Socket {
  @override
  bool connected = false;
  final handlers = <String, Function>{};
  final packets = <Map<String, dynamic>>[];
  void Function(Map<String, dynamic>, Function)? onSend;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final args = invocation.positionalArguments;
    if (invocation.memberName == #on) {
      handlers[args[0] as String] = args[1] as Function;
      return () {
        handlers.remove(args[0]);
      };
    } else if (invocation.memberName == #onConnect) {
      handlers['connect'] = args[0] as Function;
    } else if (invocation.memberName == #onDisconnect) {
      handlers['disconnect'] = args[0] as Function;
    } else if (invocation.memberName == #onConnectError) {
      handlers['connect_error'] = args[0] as Function;
    } else if (invocation.memberName == #connect) {
      connected = true;
      handlers['connect']?.call(null);
    } else if (invocation.memberName == #emitWithAck) {
      final packet = Map<String, dynamic>.from(args[1] as Map);
      packets.add(packet);
      final ack = invocation.namedArguments[#ack] as Function;
      onSend?.call(packet, ack);
    }
    return this;
  }
}

void main() {
  test(
    'a failed send reports failure and retries the same ID until persistence is confirmed',
    () async {
      final socket = TestSocket();
      final chat = ChatService(
        bookingId: 'booking',
        socketFactory: (_, _) => socket,
        tokenProvider: () => 'token',
        historyClient: MockClient((_) async => history([])),
      );
      chat.connect();
      socket.onSend = (_, ack) => ack({'success': false});
      expect(await chat.sendMessage('Are you coming?'), false);
      expect(chat.error.value, contains('not confirmed'));
      socket.onSend = (packet, ack) => ack({
        'success': true,
        'message': {
          ...message(1),
          'message': packet['message'],
          'clientMessageId': packet['clientMessageId'],
        },
      });
      expect(await chat.sendMessage('Are you coming?'), true);
      expect(socket.packets.length, 2);
      expect(
        socket.packets[0]['clientMessageId'],
        socket.packets[1]['clientMessageId'],
      );
      expect(chat.messages.value.single.message, 'Are you coming?');
      chat.dispose();
    },
  );

  test(
    'history confirms a persisted message when the socket acknowledgement was lost',
    () async {
      final socket = TestSocket();
      var requests = 0;
      final ownRole = ChatMessage.fromJson(message(0)).isMe ? 'USER' : 'DRIVER';
      final chat = ChatService(
        bookingId: 'booking',
        socketFactory: (_, _) => socket,
        tokenProvider: () => 'token',
        historyClient: MockClient((_) async {
          requests++;
          if (requests == 1) return history([]);
          return history([
            {
              ...message(1),
              'message': 'I am waiting',
              'senderType': ownRole,
              'clientMessageId': socket.packets.single['clientMessageId'],
            },
          ]);
        }),
      );
      chat.connect();
      await Future<void>.delayed(Duration.zero);
      final send = chat.sendMessage('I am waiting');
      await chat.loadHistory();
      expect(await send, true);
      expect(chat.messages.value.single.message, 'I am waiting');
      chat.dispose();
    },
  );

  test(
    'reconnecting the socket actually reloads messages missed during disconnect',
    () async {
      final socket = TestSocket();
      var requests = 0;
      final chat = ChatService(
        bookingId: 'booking',
        socketFactory: (_, _) => socket,
        tokenProvider: () => 'token',
        historyClient: MockClient((_) async {
          requests++;
          return history(
            requests == 1 ? [message(1)] : [message(1), message(2)],
          );
        }),
      );
      chat.connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      socket.connected = false;
      socket.handlers['disconnect']?.call(null);
      expect(chat.isConnected.value, false);
      socket.connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(chat.isConnected.value, true);
      expect(chat.messages.value.map((m) => m.id), ['1', '2']);
      chat.dispose();
    },
  );
  test(
    'loads the complete conversation, including messages after the first page',
    () async {
      final pages = <int>[];
      final client = MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-token');
        final page = int.parse(request.url.queryParameters['page']!);
        pages.add(page);
        return history(
          List.generate(
            page == 1 ? 100 : 20,
            (n) => message((page - 1) * 100 + n),
          ),
          pages: 2,
        );
      });
      final chat = ChatService(
        bookingId: 'booking',
        historyClient: client,
        tokenProvider: () => 'test-token',
      );
      await chat.loadHistory();
      expect(pages, [1, 2]);
      expect(chat.messages.value.length, 120);
      expect(chat.messages.value.last.message, 'Message 119');
      chat.dispose();
    },
  );

  test(
    'history merges with a live message received during the HTTP request',
    () async {
      final response = Completer<http.Response>();
      final chat = ChatService(
        bookingId: 'booking',
        historyClient: MockClient((_) => response.future),
        tokenProvider: () => 'token',
      );
      final pending = chat.loadHistory();
      chat.messages.value = [ChatMessage.fromJson(message(3))];
      response.complete(history([message(1), message(2)]));
      await pending;
      expect(chat.messages.value.map((m) => m.id), ['1', '2', '3']);
      chat.dispose();
    },
  );

  test('reloading recovers missed messages without duplicates', () async {
    var request = 0;
    final chat = ChatService(
      bookingId: 'booking',
      historyClient: MockClient((_) async {
        request++;
        return history(request == 1 ? [message(1)] : [message(1), message(2)]);
      }),
      tokenProvider: () => 'token',
    );
    await chat.loadHistory();
    await chat.loadHistory();
    expect(chat.messages.value.map((m) => m.id), ['1', '2']);
    chat.dispose();
  });

  test(
    'a reconnect during history loading schedules another recovery',
    () async {
      final first = Completer<http.Response>();
      var requests = 0;
      final chat = ChatService(
        bookingId: 'booking',
        historyClient: MockClient((_) {
          requests++;
          return requests == 1
              ? first.future
              : Future.value(history([message(1), message(2)]));
        }),
        tokenProvider: () => 'token',
      );
      final pending = chat.loadHistory();
      await Future<void>.delayed(Duration.zero);
      chat.loadHistory();
      first.complete(history([message(1)]));
      await pending;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(requests, 2);
      expect(chat.messages.value.map((m) => m.id), ['1', '2']);
      chat.dispose();
    },
  );

  test(
    'closing chat while history is pending does not publish to disposed notifiers',
    () async {
      final response = Completer<http.Response>();
      final chat = ChatService(
        bookingId: 'booking',
        historyClient: MockClient((_) => response.future),
        tokenProvider: () => 'token',
      );
      final pending = chat.loadHistory();
      chat.dispose();
      response.complete(history([message(1)]));
      await pending;
    },
  );

  test(
    'offline sends fail visibly so the screen can retain the draft',
    () async {
      final chat = ChatService(
        bookingId: 'booking',
        tokenProvider: () => 'token',
      );
      expect(await chat.sendMessage('Are you coming?'), false);
      expect(chat.error.value, contains('reconnecting'));
      expect(chat.messages.value, isEmpty);
      chat.dispose();
    },
  );

  test(
    'a failed history request preserves the messages already displayed',
    () async {
      final chat = ChatService(
        bookingId: 'booking',
        historyClient: MockClient(
          (_) async => http.Response('unavailable', 503),
        ),
        tokenProvider: () => 'token',
      );
      chat.messages.value = [ChatMessage.fromJson(message(1))];
      await chat.loadHistory();
      expect(chat.messages.value.single.id, '1');
      expect(chat.error.value, contains('Unable to load'));
      chat.dispose();
    },
  );
}
