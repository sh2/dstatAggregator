<?php

error_reporting(E_ALL|E_STRICT);

$csv_files = $_POST['csv_files'];
$arg = '';
$message = '';

foreach ($csv_files as $csv_file) {
    $arg .= escapeshellarg("rrds/{$csv_file}") . ' ';
}

exec("perl rrds2graphs.pl {$arg} 2>&1", $output, $return_var);

if ($return_var == 0) {
    header('Location: reports/');
    exit();
} else {
    foreach ($output as $line) {
        $message .= htmlspecialchars($line) . "<br />\n";
    }
}

?>
<!DOCTYPE html>
<html>
  <head>
    <title>Error - dstatAggregator</title>
  </head>
  <body>
    <p>
<?php print $message; ?>
    </p>
  </body>
</html>

