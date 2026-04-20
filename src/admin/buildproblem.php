<?php
$generating = isset($_POST['SubmitWizard']) && $_POST['SubmitWizard'] == 'Gerar ZIP';
if($generating) $_POST['noflush'] = 'true';
require('header.php');
require_once('../private/problem_builder_web.php');
if(($ct = DBContestInfo($_SESSION["usertable"]["contestnumber"])) == null)
	ForceLoad("../index.php");

function bp_html($text) {
	return htmlspecialchars($text, ENT_QUOTES, 'UTF-8');
}

function bp_error_page($msg) {
	while(ob_get_level() > 0) @ob_end_clean();
	header("Content-Type: text/html; charset=utf-8");
	echo "<html><body><script>alert('" . str_replace("'", "\\'", $msg) . "');history.back();</script></body></html>";
	exit;
}

function bp_positive_int($name, $fallback, $min=1, $max=100000) {
	$value = isset($_POST[$name]) ? trim($_POST[$name]) : '';
	if($value == '') return $fallback;
	if(!ctype_digit($value)) bp_error_page('Campo numerico invalido: ' . $name);
	$value = intval($value);
	if($value < $min || $value > $max) bp_error_page('Valor fora do limite: ' . $name);
	return $value;
}

function bp_collect_cases() {
	$inputs = isset($_POST['case_input']) && is_array($_POST['case_input']) ? $_POST['case_input'] : array();
	$outputs = isset($_POST['case_output']) && is_array($_POST['case_output']) ? $_POST['case_output'] : array();
	$cases = array();
	$total = max(count($inputs), count($outputs));
	for($i = 0; $i < $total; $i++) {
		$input = isset($inputs[$i]) ? $inputs[$i] : '';
		$output = isset($outputs[$i]) ? $outputs[$i] : '';
		if(trim($input) == '' && trim($output) == '') continue;
		if(trim($input) == '' || trim($output) == '')
			bp_error_page('Todo caso de teste precisa ter entrada e saida esperada.');
		$cases[] = array('input' => $input, 'output' => $output);
	}
	if(count($cases) == 0)
		bp_error_page('Inclua pelo menos um caso de teste.');
	return $cases;
}

function bp_collect_statement() {
	$manual = isset($_POST['statement_text']) ? trim($_POST['statement_text']) : '';
	if(isset($_FILES['statement_file']) && $_FILES['statement_file']['error'] != UPLOAD_ERR_NO_FILE) {
		if($_FILES['statement_file']['error'] != UPLOAD_ERR_OK)
			bp_error_page('Falha no upload do enunciado.');
		if(!is_uploaded_file($_FILES['statement_file']['tmp_name']))
			bp_error_page('Upload invalido do enunciado.');
		$name = bpw_sanitize_filename($_FILES['statement_file']['name'], 'statement.pdf');
		$ext = strtolower(pathinfo($name, PATHINFO_EXTENSION));
		if(!in_array($ext, array('pdf', 'txt', 'md', 'tex')))
			bp_error_page('Use enunciado em PDF, TXT, MD ou TEX.');
		$content = file_get_contents($_FILES['statement_file']['tmp_name']);
		if($content === false || strlen($content) == 0)
			bp_error_page('Nao foi possivel ler o enunciado enviado.');
		return array($name, $content);
	}
	if($manual == '')
		bp_error_page('Informe o enunciado manualmente ou envie um arquivo.');
	return array('statement.md', "# Enunciado\n\n" . $manual . "\n");
}

function bp_generate_zip() {
	$basename = isset($_POST['basename']) ? bpw_sanitize_filename($_POST['basename'], '') : '';
	$fullname = isset($_POST['fullname']) ? trim($_POST['fullname']) : '';
	if($basename == '') bp_error_page('Informe o basename do problema.');
	if($fullname == '') bp_error_page('Informe o nome completo do problema.');
	$languages = isset($_POST['languages']) && is_array($_POST['languages']) ? $_POST['languages'] : array('py3');
	list($statementName, $statementContent) = bp_collect_statement();
	$spec = array(
		'basename' => $basename,
		'fullname' => $fullname,
		'time' => bp_positive_int('time_limit', 1, 1, 300),
		'repetitions' => bp_positive_int('repetitions', 1, 1, 100),
		'memory' => bp_positive_int('memory_limit', 512, 16, 32768),
		'output' => bp_positive_int('output_limit', 1024, 1, 1048576),
		'languages' => $languages,
		'statement_name' => $statementName,
		'statement_content' => $statementContent,
		'cases' => bp_collect_cases()
	);
	$temp = tempnam(sys_get_temp_dir(), 'boca_problem_');
	if($temp === false) bp_error_page('Nao foi possivel criar arquivo temporario.');
	@unlink($temp);
	$zipPath = $temp . '.zip';
	try {
		bpw_create_package(dirname(__DIR__, 2), $spec, $zipPath);
		$data = file_get_contents($zipPath);
		@unlink($zipPath);
		if($data === false) bp_error_page('Nao foi possivel ler o ZIP gerado.');
		while(ob_get_level() > 0) @ob_end_clean();
		header("Expires: " . gmdate("D, d M Y H:i:s") . " GMT");
		header("Last-Modified: " . gmdate("D, d M Y H:i:s") . " GMT");
		header("Cache-Control: no-cache, must-revalidate");
		header("Pragma: no-cache");
		header("Content-Type: application/zip");
		header("Content-Disposition: attachment; filename=\"" . $basename . ".zip\"");
		echo $data;
		exit;
	} catch(Exception $e) {
		@unlink($zipPath);
		bp_error_page($e->getMessage());
	}
}

if($generating) bp_generate_zip();
$langs = bpw_allowed_languages();
?>
<style>
.cc-builder { width: 94%; margin: 18px auto 40px auto; }
.cc-panel { border: 1px solid #555555; background: #efefdf; padding: 14px; }
.cc-head { width: 100%; border-collapse: collapse; background: #eeee00; border: 1px solid #555555; }
.cc-head td { padding: 10px; vertical-align: middle; }
.cc-logo { width: 118px; height: auto; display: block; }
.cc-title { font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 18pt; font-weight: bold; }
.cc-subtitle { font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 10pt; margin-top: 4px; }
.cc-section { margin-top: 14px; border: 1px solid #555555; background: #dfdfdf; }
.cc-section-title { background: #d0d0c0; padding: 7px 9px; font-family: Verdana, Arial, Helvetica, sans-serif; font-weight: bold; border-bottom: 1px solid #555555; }
.cc-section-body { padding: 10px; }
.cc-grid { width: 100%; border-collapse: collapse; }
.cc-grid td { padding: 5px; vertical-align: top; }
.cc-label { width: 230px; text-align: right; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 11pt; }
.cc-help { color: #333333; font-size: 10pt; }
.cc-case { width: 100%; border-collapse: collapse; margin-bottom: 8px; }
.cc-case th { background: #eeee00; border: 1px solid #555555; padding: 4px; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 10pt; }
.cc-case td { border: 1px solid #555555; background: #f7f7ef; padding: 4px; }
.cc-case textarea { width: 98%; height: 95px; font-family: "Courier New", Courier, mono; font-size: 10pt; }
.cc-actions { text-align: center; margin-top: 14px; }
.cc-warning { border: 1px solid #aa8800; background: #fff8bf; padding: 8px; margin-top: 8px; font-family: Verdana, Arial, Helvetica, sans-serif; font-size: 10pt; }
.cc-small-button { font-size: 10pt; }
@media (max-width: 760px) {
	.cc-builder { width: 98%; }
	.cc-logo { width: 82px; }
	.cc-title { font-size: 14pt; }
	.cc-label { width: auto; text-align: left; display: block; }
	.cc-grid td { display: block; width: 100%; }
}
</style>
<script language="javascript">
function addCase() {
	var area = document.getElementById('cases');
	var total = area.getElementsByTagName('table').length + 1;
	var table = document.createElement('table');
	table.className = 'cc-case';
	table.innerHTML = '<tr><th colspan="2">Caso de teste ' + total + '</th></tr>' +
		'<tr><td width="50%">Entrada<br><textarea name="case_input[]"></textarea></td>' +
		'<td width="50%">Saida esperada<br><textarea name="case_output[]"></textarea></td></tr>';
	area.appendChild(table);
}
function removeCase() {
	var area = document.getElementById('cases');
	var tables = area.getElementsByTagName('table');
	if(tables.length > 1) area.removeChild(tables[tables.length - 1]);
}
function validateBuilder() {
	if(document.formbuilder.fullname.value == '' || document.formbuilder.basename.value == '') {
		alert('Informe o nome completo e o basename.');
		return false;
	}
	var inputs = document.getElementsByName('case_input[]');
	var outputs = document.getElementsByName('case_output[]');
	var ok = false;
	for(var i = 0; i < inputs.length; i++) {
		if(inputs[i].value.replace(/\s/g, '') != '' && outputs[i].value.replace(/\s/g, '') != '') ok = true;
	}
	if(!ok) {
		alert('Inclua pelo menos um caso de teste completo.');
		return false;
	}
	return true;
}
</script>
<div class="cc-builder">
	<table class="cc-head">
		<tr>
			<td width="130" align="center"><img class="cc-logo" src="../images/caramel-coders.png" alt="Caramel Coders"></td>
			<td>
				<div class="cc-title">Gerador de Problemas BOCA</div>
				<div class="cc-subtitle">Interface Caramel Coders para montar o ZIP de questao sem editar pastas, scripts ou arquivos internos.</div>
			</td>
			<td align="right" nowrap><a class="menu" href="problem.php">Voltar para Problems</a></td>
		</tr>
	</table>
	<form name="formbuilder" enctype="multipart/form-data" method="post" action="buildproblem.php" onsubmit="return validateBuilder();">
		<div class="cc-section">
			<div class="cc-section-title">Dados do problema</div>
			<div class="cc-section-body">
				<table class="cc-grid">
					<tr>
						<td class="cc-label">Nome completo:</td>
						<td><input type="text" name="fullname" size="60" maxlength="100" value=""> <span class="cc-help">Exemplo: Soma Simples</span></td>
					</tr>
					<tr>
						<td class="cc-label">Basename:</td>
						<td><input type="text" name="basename" size="30" maxlength="60" value=""> <span class="cc-help">Sem espacos. Exemplo: soma</span></td>
					</tr>
					<tr>
						<td class="cc-label">Tempo:</td>
						<td><input type="text" name="time_limit" size="6" value="1"> segundos &nbsp; Repeticoes: <input type="text" name="repetitions" size="6" value="1"></td>
					</tr>
					<tr>
						<td class="cc-label">Memoria e saida:</td>
						<td><input type="text" name="memory_limit" size="8" value="512"> MB &nbsp; <input type="text" name="output_limit" size="8" value="1024"> KB</td>
					</tr>
					<tr>
						<td class="cc-label">Linguagens:</td>
						<td>
<?php foreach($langs as $key => $label) { ?>
							<label><input type="checkbox" name="languages[]" value="<?php echo bp_html($key); ?>"<?php if($key == 'py3') echo ' checked'; ?>> <?php echo bp_html($label); ?></label>&nbsp;&nbsp;
<?php } ?>
							<div class="cc-warning">O autoteste interno do pacote usa Python3 por padrao para evitar falha do jail quando C/C++ nao estiver instalado.</div>
						</td>
					</tr>
				</table>
			</div>
		</div>
		<div class="cc-section">
			<div class="cc-section-title">Enunciado</div>
			<div class="cc-section-body">
				<table class="cc-grid">
					<tr>
						<td class="cc-label">Arquivo pronto:</td>
						<td><input type="file" name="statement_file" size="45"> <span class="cc-help">PDF, TXT, MD ou TEX.</span></td>
					</tr>
					<tr>
						<td class="cc-label">Ou texto manual:</td>
						<td><textarea class="edit" name="statement_text" rows="10" cols="90"></textarea></td>
					</tr>
				</table>
			</div>
		</div>
		<div class="cc-section">
			<div class="cc-section-title">Casos de teste</div>
			<div class="cc-section-body">
				<div id="cases">
					<table class="cc-case">
						<tr><th colspan="2">Caso de teste 1</th></tr>
						<tr>
							<td width="50%">Entrada<br><textarea name="case_input[]"></textarea></td>
							<td width="50%">Saida esperada<br><textarea name="case_output[]"></textarea></td>
						</tr>
					</table>
				</div>
				<input type="button" class="cc-small-button" value="Adicionar caso" onclick="addCase();">
				<input type="button" class="cc-small-button" value="Remover ultimo" onclick="removeCase();">
			</div>
		</div>
		<div class="cc-actions">
			<input type="submit" name="SubmitWizard" value="Gerar ZIP">
			<input type="reset" value="Limpar">
		</div>
	</form>
	<div class="cc-warning">Depois de baixar o ZIP, volte para Problems, escolha o numero e nome curto do problema, envie o pacote em Problem package (ZIP) e confirme.</div>
</div>
</body>
</html>
