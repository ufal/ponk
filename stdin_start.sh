
echo "Analyzing input text" >err

echo "Paní Nováková pracuje ve firmě Česká plynárenská, s.r.o." |\
./system/ponk.pl --stdin --output-format txt 2>>err

echo "Analysis finished." >>err
