<?php

error_reporting(E_ALL|E_STRICT);

function get_report_dir() {
    $chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    $report_dir = 'reports/' . date('Ymd-His_');
    
    for ($i = 0; $i < 8; $i++) {
        $report_dir .= $chars{mt_rand(0, strlen($chars) - 1)};
    }
    
    return $report_dir;
}

function validate_number($input, $min, $max, $default) {
    if (preg_match('/^\d+$/D', $input)) {
        if ($input < $min) {
            return $min;
        } elseif ($input > $max) {
            return $max;
        } else {
            return $input;
        }
    } else {
        return $default;
    }
}

$ids = $_POST['ids'];
$report_dir = get_report_dir();
$width      = validate_number($_POST['width'], 64, 1024, 512);
$height     = validate_number($_POST['height'], 64, 1024, 192);
$disk_limit = validate_number($_POST['disk_limit'], 0, PHP_INT_MAX, 0);
$net_limit  = validate_number($_POST['net_limit'], 0, PHP_INT_MAX, 0);
$args = '';
$message = '';

if ($_POST['switch'] === 'aggregate') {
    foreach ($ids as $id) {
        $rrd_file = sprintf("rrds/%05d_{$_POST["rrd{$id}"]}.rrd", $id);
        $hostname = $_POST["host{$id}"];
        $disk = $_POST["disk{$id}"];
        $net = $_POST["net{$id}"];
        $args .= escapeshellarg("{$rrd_file}:{$hostname}:{$disk}:{$net}") . ' ';
    }
    
    exec("perl rrds2graphs.pl {$report_dir} {$width} {$height} {$disk_limit} {$net_limit} {$args} 2>&1",
        $output, $return_var);
    
    if ($return_var == 0) {
        header("Location: {$report_dir}/");
        exit();
    } else {
        foreach ($output as $line) {
            $message .= htmlspecialchars($line) . "<br />\n";
        }
    }    
} elseif ($_POST['switch'] === 'delete') {
    $conn = new mysqli('localhost', 'rstat', 'rstat', 'rstat');
    
    if ($conn->connect_errno) {
        die('Connection Failed: ' . $conn->connect_errno);
    }
    
    $conn->set_charset('utf8');
    $conn->autocommit(FALSE);
    $stmt = $conn->prepare('DELETE FROM rrd WHERE id = ?');
    
    foreach ($ids as $id) {
        $stmt->bind_param('i', $id);
        $stmt->execute();
    }
    
    $stmt->close();
    $conn->commit();
    $conn->close();
    
    foreach ($ids as $id) {
        $rrd_file = sprintf("rrds/%05d_{$_POST["rrd{$id}"]}.rrd", $id);
        unlink($rrd_file);
    }
    
    header("Location: .");
    exit();
}

?>
<!DOCTYPE html>
<html>
  <head>
    <title>Error - dstatAggregator</title>
  </head>
  <body>
    <p>
<?php echo $message; ?>
    </p>
  </body>
</html>

