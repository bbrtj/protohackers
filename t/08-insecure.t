use v5.42;

use Test2::V0;
use Module::Insecure::CipherStack;
use Module::Insecure;
use SessionMock;

subtest 'should have a working cipher' => sub {
	my $cipher = Module::Insecure::CipherStack->new;
	$cipher->add_cipher("\x02\x7b\x05\x01");
	$cipher->finalize;

	is $cipher->decipher("\xf2\x20\xba\x44\x18\x84\xba\xaa\xd0\x26\x44\xa4\xa8\x7e"), "4x dog,5x car\n",
		'decipher ok';
	is $cipher->cipher("5x car\n"), "\x72\x20\xba\xd8\x78\x70\xee", 'cipher ok';
};

subtest 'should detect no-op ciphers' => sub {
	my $cipher = Module::Insecure::CipherStack->new;
	my $ex = dies {
		$cipher->add_cipher("\x02\xa0\x02\x0b\x02\xab");
		$cipher->finalize;
	};

	isa_ok $ex, 'X::ShouldDisconnect';
};

subtest 'should decipher longer text' => sub {
	my $cipher = Module::Insecure::CipherStack->new;
	$cipher->add_cipher("\x03\x04\x07\x03");
	$cipher->finalize;

	my $data = join '',
		map { chr } (
			61, 58, 131, 41, 107, 118, 97, 110, 36, 136, 96, 115, 124, 57, 100, 126, 123, 102, 151, 41,
			121, 98, 148, 104, 107, 154, 36, 100, 102, 103, 111, 107, 118, 117, 119, 110, 99, 41, 119, 104,
			73, 75, 112, 57, 115, 100, 112, 37, 58, 56, 99, 41, 80, 87, 97, 85, 88, 109, 88, 91,
			107, 98, 27, 91, 108, 102, 117, 41, 115, 116, 0, 53, 204, 207, 115, 57, 10, 106, 120, 101,
			19, 41, 16, 23, 109, 21, 104, 125, 24, 27, 103, 30, 223, 110, 108, 26, 107, 104, 118, 121,
			115, 98, 125, 41, 74, 110, 100, 78, 107, 126, 79, 104, 121, 21, 60, 59, 103, 41, 87, 82,
			93, 90, 36, 116, 96, 115, 92, 25, 126, 116, 118, 109, 108, 119, 43, 109, 140, 120, 98, 38,
			121, 102, 103, 101, 108, 109, 43, 121, 107, 110, 127, 98, 119, 106, 106, 89, 102, 103, 91, 154,
			39, 120, 127, 123, 112, 119, 110, 53, 13, 8, 115, 57, 126, 102, 120, 103, 123, 41, 84, 110,
			115, 110, 87, 41, 96, 103, 89, 101, 88, 109, 88, 91, 115, 106, 43, 100, 104, 123, 43, 125,
			102, 126, 39, 207, 206, 113, 59, 96, 16, 102, 17, 125, 47, 109, 124, 108, 98, 34, 101, 98,
			107, 101, 28, 29, 39, 121, 119, 106, 115, 70, 123, 126, 74, 57, 78, 98, 115, 97, 59, 98,
			85, 111, 87, 106, 115, 110, 109, 85, 92, 25, 88, 94, 105, 100, 107, 101, 104, 119, 108, 41,
			115, 116, 128, 53, 63, 73, 115, 57, 143, 100, 122, 100, 108, 125, 84, 116, 144, 99, 108, 41,
			154, 106, 159, 157, 107, 118, 91, 159, 121, 116, 110, 41, 118, 119, 43, 106, 39, 72, 79, 75,
			96, 103, 126, 37, 63, 62, 99, 41, 107, 86, 97, 110, 36, 104, 96, 115, 92, 25, 96, 103,
			109, 117, 104, 125, 104, 107, 119, 110, 39, 125, 12, 100, 98, 42, 125, 98, 19, 21, 108, 109,
			47, 121, 23, 106, 107, 126, 107, 110, 106, 217, 102, 103, 39, 102, 43, 116, 115, 123, 112, 119,
			126, 37, 48, 9, 119, 57, 75, 104, 106, 80, 108, 125, 20, 120, 80, 99, 92, 25, 110, 96,
			102, 93, 92, 103, 39, 121, 118, 119, 128, 53, 63, 65, 127, 57, 96, 103, 125, 101, 120, 141,
			104, 107, 151, 110, 47, 144, 150, 150, 102, 157, 102, 89, 99, 107, 152, 96, 118, 119, 43, 125,
			118, 70, 55, 58, 55, 9, 115, 57, 79, 100, 122, 100, 108, 125, 20, 116, 80, 99, 108, 41,
			119, 101, 88, 116, 115, 102, 90, 25, 104, 117, 119, 114, 110, 110, 127, 104, 9, 57, 102, 103,
			63, 126, 59, 12, 123, 123, 16, 23, 110, 213, 35, 60, 127, 217, 110, 96, 102, 29, 28, 103,
			39, 123, 108, 118, 118, 125, 108, 54, 122, 100, 97, 77, 73, 100, 103, 101, 108, 109, 43, 122,
			124, 110, 111, 108, 102, 105, 111, 94, 105, 25, 111, 104, 128, 53, 60, 61, 135, 41, 119, 114,
			125, 122, 36, 116, 96, 115, 124, 57, 126, 148, 150, 109, 108, 151, 43, 109, 102, 156, 91, 116,
			96, 106, 108, 101, 104, 125, 118, 123, 43, 62, 67, 41, 119, 100, 122, 108, 124, 77, 36, 76,
			80, 99, 108, 41, 80, 87, 97, 85, 88, 109, 88, 91, 107, 98, 27, 96, 118, 102, 127, 41,
			115, 116, 0, 53, 202, 113, 59, 9, 107, 126, 10, 13, 16, 104, 43, 106, 108, 123, 22, 121,
			99, 102, 97, 30, 223, 104, 96, 102, 124, 117, 104, 125, 118, 123, 55, 61, 14, 113, 59, 101,
			96, 127, 124, 38, 122, 110, 125, 110, 47, 106, 108, 125, 88, 101, 27, 101, 88, 105, 111, 104,
			119, 41, 126, 114, 115, 113, 43, 108, 120, 139, 117, 114, 63, 120, 120, 140, 108, 85, 32, 56,
			103, 41, 122, 150, 152, 101, 103, 89, 106, 100, 97, 109, 39, 123, 124, 107, 105, 98, 125, 41,
			73, 122, 100, 96, 115, 98, 36, 124, 86, 87, 127, 123, 86, 85, 87, 110, 91, 25, 104, 110,
			88, 93, 90, 104, 119, 125, 108, 123, 47, 116, 105, 41, 120, 57, 10, 13, 9, 102, 105, 96,
			211, 62, 60, 97, 47, 121, 22, 108, 98, 26, 111, 38, 106, 102, 117, 30, 39, 112, 118, 118,
			118, 109, 118, 41, 123, 75, 120, 120, 102, 103, 59, 112, 80, 125, 83, 41, 77, 89, 81, 41,
			92, 34, 106, 100, 102, 100, 111, 94, 121, 41, 122, 114, 116, 114, 119, 106, 139, 100, 117, 37,
			74, 75, 115, 57, 122, 146, 104, 149, 107, 41, 123, 149, 152, 104, 111, 98, 154, 89, 109, 104,
			106, 112, 112, 119, 110, 41, 115, 104, 73, 72, 124, 57, 78, 102, 79, 97, 39, 104, 104, 123,
			121, 102, 43, 108, 88, 104, 92, 37, 42, 47, 115, 25, 119, 116, 106, 108, 108, 125, 52, 124,
			96, 115, 124, 57, 122, 114, 127, 125, 19, 126, 43, 106, 107, 21, 16, 96, 24, 109, 102, 107,
			223, 104, 96, 102, 124, 117, 104, 125, 118, 123, 55, 2, 63, 113, 59, 120, 96, 126, 105, 77,
			39, 102, 87, 85, 80, 108, 104, 125, 102, 107, 27, 96, 101, 25, 88, 25, 122, 125, 117, 114,
			117, 108, 55, 48, 74, 113, 59, 120, 96, 126, 105, 141, 39, 110, 145, 111, 107, 110, 127, 106,
			153, 101, 156, 89, 154, 158, 111, 37, 62, 56, 67, 41, 127, 116, 106, 116, 124, 77, 36, 116,
			96, 115, 124, 57, 122, 84, 105, 125, 47, 123, 124, 107, 89, 90, 117, 25, 105, 98, 100, 104,
			123, 106, 52, 100, 118, 119, 127, 123, 102, 101, 103, 126, 99, 57, 122, 122, 121, 41, 127, 16,
			96, 213, 61, 33, 127, 217, 26, 110, 99, 29, 103, 114, 39, 112, 118, 118, 118, 109, 118, 41,
			123, 75, 120, 120, 102, 103, 59, 76, 80, 82, 124, 85, 104, 125, 86, 123, 35, 42, 40, 113,
			31, 92, 96, 90, 117, 125, 43, 113, 118, 123, 122, 110, 39, 140, 96, 141, 103, 57, 122, 122,
			121, 123, 96, 41, 106, 110, 122, 110, 1
		);

	like $cipher->decipher($data), qr/32x small plastic rocking horse with carry case/,
		'decipher ok';
};

subtest 'should serve connections' => sub {
	my $elf = SessionMock->new;
	my $module = Module::Insecure->new;

	$module->connected($elf);
	$module->process_message($elf, "\x02\x7b\x05\x01\x00");
	$module->process_message($elf, "\xf2\x20\xba\x44\x18\x84\xba\xaa\xd0\x26");
	$module->process_message($elf, "\x44\xa4\xa8\x7e");
	$module->process_message($elf, "\x6a\x48\xd6\x58\x34\x44\xd6\x7a\x98\x4e\x0c\xcc\x94\x31");
	is $elf->_written, [
		"\x72\x20\xba\xd8\x78\x70\xee",
		"\xf2\xd0\x26\xc8\xa4\xd8\x7e",
		],
		'data received ok';

	$module->disconnected($elf);

	ok $elf->_closed, 'session is closed';
};

done_testing;

