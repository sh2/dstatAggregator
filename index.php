<!DOCTYPE html>
<html>
  <head>
    <meta charset="UTF-8">
    <title>dstatAggregator</title>
  </head>
  <body>
    <h1>dstatAggregator</h1>
    <p>他の二つほどきちんとエラー処理していないので気をつけてください。</p>
    <form action="dstat2rrd.php" method="post" enctype="multipart/form-data">
      <fieldset>
        <legend>ファイル登録</legend>
        <input type="file" name="csv_file" size="50" />
        <input type="submit" value="Upload" />
      </fieldset>
    </form>
    <form action="rrds2graphs.php" method="post">
      <fieldset>
        <legend>グラフ作成</legend>
<?php
error_reporting(E_ALL|E_STRICT);
$rrds_dir = 'rrds';
$rrd_list = array();

if ($handle = opendir($rrds_dir)) {
    while (false !== ($rrd_file = readdir($handle))) {
        if (preg_match('/\.rrd$/', $rrd_file)) {
            array_push($rrd_list, $rrd_file);
        }
    }
    
    closedir($handle);
}

sort($rrd_list);

foreach ($rrd_list as $rrd_file) {
    $mtime = filemtime("$rrds_dir/$rrd_file");
?>
        <label for="<?php echo $rrd_file; ?>">
          <input type="checkbox" name="csv_files[]" value="<?php echo $rrd_file; ?>" id="<?php echo $rrd_file; ?>" />
          <?php echo $rrd_file; ?> (<?php echo date('Y/m/d H:i:s', $mtime); ?>)
        </label>
        <br />
<?php 
}
?>
        <label for="aggregate">
          <input type="radio" name="switch" value="aggregate" id="aggregate" checked />
          Aggregate
        </label>
        <label for="delete">
          <input type="radio" name="switch" value="delete" id="delete" />
          Delete(まだ)
        </label>
        <br />
        <input type="submit" value="Submit" />
        <input type="reset" value="Reset" />
      </fieldset>
    </form>
    <hr />
    (c) 2012, Sadao Hiratsuka.
  </body>
</html>

