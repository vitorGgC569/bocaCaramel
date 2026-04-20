<?php
function bpw_allowed_languages() {
	return array(
		'c' => 'C',
		'cpp' => 'C++20',
		'java' => 'Java',
		'kt' => 'Kotlin',
		'py3' => 'Python3'
	);
}

function bpw_sanitize_filename($name, $fallback) {
	$name = basename(trim($name));
	$name = preg_replace('/[^A-Za-z0-9_.-]/', '_', $name);
	$name = trim($name, '._-');
	if($name == '') $name = $fallback;
	return $name;
}

function bpw_normalize_newlines($text) {
	return str_replace(array("\r\n", "\r"), "\n", $text);
}

function bpw_mkdir($dir) {
	if(!is_dir($dir) && !@mkdir($dir, 0770, true))
		throw new Exception('Nao foi possivel criar a pasta temporaria do pacote.');
}

function bpw_write_file($path, $content, $mode=0640) {
	if(file_put_contents($path, $content) === false)
		throw new Exception('Nao foi possivel gravar arquivo temporario do pacote.');
	@chmod($path, $mode);
}

function bpw_copy_file($source, $target, $mode=0755) {
	if(!is_readable($source))
		throw new Exception('Template BOCA ausente: ' . $source);
	if(!@copy($source, $target))
		throw new Exception('Nao foi possivel copiar template BOCA.');
	@chmod($target, $mode);
}

function bpw_remove_dir($dir) {
	if(!is_dir($dir)) return;
	$items = new RecursiveIteratorIterator(
		new RecursiveDirectoryIterator($dir, FilesystemIterator::SKIP_DOTS),
		RecursiveIteratorIterator::CHILD_FIRST
	);
	foreach($items as $item) {
		if($item->isDir()) @rmdir($item->getPathname());
		else @unlink($item->getPathname());
	}
	@rmdir($dir);
}

function bpw_language_list($languages) {
	$allowed = bpw_allowed_languages();
	$out = array();
	foreach($languages as $language) {
		$language = trim($language);
		if(isset($allowed[$language]) && !in_array($language, $out))
			$out[] = $language;
	}
	if(count($out) == 0) $out[] = 'py3';
	return $out;
}

function bpw_test_script() {
	return "#!/bin/bash\n" .
		"set -e\n" .
		"cat > test.py <<'EOF'\n" .
		"import sys\n" .
		"print(sys.stdin.read().strip())\n" .
		"EOF\n" .
		"cat > test.in <<'EOF'\n" .
		"inputdata\n" .
		"EOF\n" .
		"TL=2\n" .
		"REP=1\n" .
		"chmod 755 ../compile/py3\n" .
		"../compile/py3 test.py test.exe \$TL\n" .
		"chmod 755 ../run/py3\n" .
		"../run/py3 test.exe test.in \$TL \$REP\n" .
		"output=\$(cat stdout0 2>/dev/null || true)\n" .
		"if [ \"\$output\" != \"inputdata\" ]; then\n" .
		"  echo \"ERROR\"\n" .
		"  exit 1\n" .
		"fi\n" .
		"echo \"TEST PASSED\"\n" .
		"exit 0\n";
}

function bpw_limit_script($time, $repetitions, $memory, $output) {
	return "#!/bin/bash\n" .
		"echo " . intval($time) . "\n" .
		"echo " . intval($repetitions) . "\n" .
		"echo " . intval($memory) . "\n" .
		"echo " . intval($output) . "\n" .
		"exit 0\n";
}

function bpw_add_to_zip($zip, $stage, $path) {
	$relative = str_replace('\\', '/', substr($path, strlen($stage) + 1));
	if($relative == '' || strpos($relative, '..') !== false)
		throw new Exception('Caminho invalido no pacote.');
	if(is_dir($path)) return;
	if(!$zip->addFile($path, $relative))
		throw new Exception('Nao foi possivel adicionar arquivo ao ZIP.');
	if(method_exists($zip, 'setExternalAttributesName')) {
		$first = explode('/', $relative);
		$exec = in_array($first[0], array('compile', 'run', 'compare', 'limits', 'tests'));
		$mode = $exec ? 0100755 : 0100644;
		@$zip->setExternalAttributesName($relative, ZipArchive::OPSYS_UNIX, $mode << 16);
	}
}

function bpw_zip_dir($stage, $zipPath) {
	if(!class_exists('ZipArchive'))
		throw new Exception('Extensao ZipArchive nao esta disponivel no PHP.');
	$zip = new ZipArchive();
	if($zip->open($zipPath, ZipArchive::CREATE | ZipArchive::OVERWRITE) !== true)
		throw new Exception('Nao foi possivel criar o ZIP.');
	$items = new RecursiveIteratorIterator(
		new RecursiveDirectoryIterator($stage, FilesystemIterator::SKIP_DOTS),
		RecursiveIteratorIterator::SELF_FIRST
	);
	foreach($items as $item)
		bpw_add_to_zip($zip, $stage, $item->getPathname());
	$zip->close();
	if(!is_readable($zipPath))
		throw new Exception('ZIP final nao foi gerado.');
}

function bpw_create_package($repoRoot, $spec, $zipPath) {
	$ds = DIRECTORY_SEPARATOR;
	$template = $repoRoot . $ds . 'doc' . $ds . 'problemexamples' . $ds . 'problemtemplate';
	if(!is_dir($template))
		throw new Exception('Template de problemas BOCA nao encontrado.');
	$stage = $zipPath . '_stage';
	bpw_remove_dir($stage);
	$dirs = array('description', 'input', 'output', 'limits', 'compile', 'run', 'compare', 'tests');
	foreach($dirs as $dir)
		bpw_mkdir($stage . $ds . $dir);
	$languages = bpw_language_list($spec['languages']);
	$scriptLanguages = $languages;
	if(!in_array('py3', $scriptLanguages))
		$scriptLanguages[] = 'py3';
	foreach($scriptLanguages as $language) {
		foreach(array('compile', 'run', 'compare') as $folder)
			bpw_copy_file($template . $ds . $folder . $ds . $language, $stage . $ds . $folder . $ds . $language);
		bpw_write_file($stage . $ds . 'limits' . $ds . $language, bpw_limit_script($spec['time'], $spec['repetitions'], $spec['memory'], $spec['output']), 0755);
	}
	bpw_write_file($stage . $ds . 'tests' . $ds . 'py3', bpw_test_script(), 0755);
	$statementName = bpw_sanitize_filename($spec['statement_name'], 'statement.md');
	bpw_write_file($stage . $ds . 'description' . $ds . $statementName, $spec['statement_content'], 0640);
	$info = "basename=" . $spec['basename'] . "\n" .
		"fullname=" . $spec['fullname'] . "\n" .
		"descfile=" . $statementName . "\n";
	bpw_write_file($stage . $ds . 'description' . $ds . 'problem.info', $info, 0640);
	bpw_write_file($stage . $ds . 'description' . $ds . 'caramel-coders.txt', "Caramel Coders BOCA\n", 0640);
	$count = 1;
	foreach($spec['cases'] as $case) {
		$name = sprintf('%03d', $count);
		bpw_write_file($stage . $ds . 'input' . $ds . $name, bpw_normalize_newlines($case['input']), 0640);
		bpw_write_file($stage . $ds . 'output' . $ds . $name, bpw_normalize_newlines($case['output']), 0640);
		$count++;
	}
	try {
		bpw_zip_dir($stage, $zipPath);
	} catch(Exception $e) {
		bpw_remove_dir($stage);
		throw $e;
	}
	bpw_remove_dir($stage);
	return array(
		'zip' => $zipPath,
		'languages' => $languages,
		'cases' => count($spec['cases'])
	);
}
?>
