
echo "Analyzing input text" >err

FILE=data/pokus.md

./system/ponk.pl --input-file $FILE --output-format conllu 2>>err

echo "Analysis finished." >>err
