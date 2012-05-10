<?php

// error_reporting(E_ALL|E_STRICT);

$csv_file = escapeshellarg($_FILES['csv_file']['tmp_name']);
$rrd_name = escapeshellarg(preg_replace('/\..*$/', '', $_FILES['csv_file']['name']));
$message  = '';

if (is_uploaded_file($_FILES['csv_file']['tmp_name'])) {
    exec("perl dstat2rrd.pl {$csv_file} {$rrd_name} 2>&1",
        $output, $return_var);
    
    if ($return_var == 0) {
        header("Location: .");
        exit();
    } else {
        foreach ($output as $line) {
            $message .= htmlspecialchars($line) . "<br />\n";
        }
    }
} else {
    if (($_FILES['csv_file']['error'] == UPLOAD_ERR_INI_SIZE)
        || ($_FILES['csv_file']['error'] == UPLOAD_ERR_FORM_SIZE)) {
        
        $message = "File size limit exceeded.\n";
    } else {
        $message = "Failed to upload file.\n";
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
