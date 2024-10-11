
<?php
// Spuštění session pro uchovávání jazyka mezi požadavky
session_start();

// Změna jazyka přes GET parametr
if (isset($_GET['lang']) && $_GET['lang'] !== $_SESSION['lang']) {
    $_SESSION['lang'] = $_GET['lang'];
    
    // Získání aktuální URL bez lang parametru
    $baseUrl = '/ponk';
    $currentUrlWithoutLang = preg_replace('/(\?|&)lang=[^&]*/', '', $_SERVER['REQUEST_URI']);
    
    // Přesměrování na URL bez lang parametru
    header("Location: " . $baseUrl . $currentUrlWithoutLang);
    exit();
}

// Nastavení defaultního jazyka, pokud není nastavený
if (!isset($_SESSION['lang'])) {
    $_SESSION['lang'] = 'cs'; // Defaultní jazyk je český
}

// Načtení jazykového souboru
require 'lang.php';

// Uložení aktuálního jazyka do proměnné pro snadnější použití
$currentLang = $_SESSION['lang'];
?>

<!DOCTYPE html>
<html>
<head>
  <title>PONK</title>
  <meta charset="utf-8">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.6.0/css/all.min.css"> <!-- Aktualizovaná verze Font Awesome -->
  <link rel="stylesheet" href="css/lindat.css" type="text/css" />
  <link rel="stylesheet" href="css/ponk.css" type="text/css" />

  <script src="https://code.jquery.com/jquery-1.11.3.min.js" type="text/javascript"></script>
  <!-- Bootstrap 5 JavaScript, nyní bez jQuery -->
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  <script src="https://cdn.rawgit.com/google/code-prettify/master/loader/run_prettify.js" type="text/javascript"></script>
</head>

<body id="lindat-services">
  <!--?php require('branding/header.htm')?-->
  <div class="lindat-common">
    <div class="container">

      <!-- Service title -->
      <h1 class="text-center pt-lg-3">PONK</h1>

      <!-- menu -->
      <div class="menu-container position-relative"> <!-- Bootstrap 5 používá position-relative místo style -->
        <ul class="nav nav-tabs nav-tabs-gray justify-content-center mb-3"> <!-- text-center je nahrazeno justify-content-center, margin-bottom: 10px je mb-3 -->
          <li class="nav-item">
            <a class="nav-link <?php if ($main_page == 'info.php') echo 'active'; ?>" href="info.php">
              <span class="fa fa-info-circle"></span> <?php echo $lang[$currentLang]['menu_about']; ?>
            </a>
          </li>
          <li class="nav-item">
            <a class="nav-link <?php if ($main_page == 'run.php') echo 'active'; ?>" href="run.php">
              <span class="fa fa-cogs"></span> <?php echo $lang[$currentLang]['menu_run']; ?>
            </a>
          </li>
          <li class="nav-item">
            <a class="nav-link <?php if ($main_page == 'api-reference.php') echo 'active'; ?>" href="api-reference.php">
              <span class="fa fa-list"></span> <?php echo $lang[$currentLang]['menu_api']; ?>
            </a>
          </li>
          <!-- Přidání vlaječek pro změnu jazyka -->
          <?php
            if ($currentLang == 'cs') {
          ?>
              <li class="nav-item position-absolute" style="right: 10px;">
                <a href="?lang=en" class="nav-link p-0"> <!-- p-0 odstraní padding, aby ikona nebyla příliš velká -->
                  <img src="img/flag_en.png" alt="English" style="height: 18px;">
                </a>
              </li>
          <?php
            } else { 
          ?>
              <li class="nav-item position-absolute" style="right: 10px;">
                <a href="?lang=cs" class="nav-link p-0">
                  <img src="img/flag_cs.png" alt="čeština" style="height: 18px;">
                </a>
              </li>
          <?php
            }
          ?>
        </ul>
      </div>
