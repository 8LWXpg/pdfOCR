param (
    [Parameter(ValueFromPipeline = $true)]
    [System.IO.FileInfo]$pdf,
    [int]$spilt = 5
)
if ($pdf.Extension -ne '.pdf') {
    'no exist file or pdf'
    return
}
$pages = [Convert]::ToInt32( ((pdftk.exe $pdf dump_data_utf8 | Select-String 'NumberOfPages').ToString() -replace "[^0-9]", ''), 10)
if (!$?) {
    return
}
$TempFolder = "$env:temp\pdfOCR"
mkdir $TempFolder -Force | Out-Null
$spilt = $spilt -gt $pages ? $pages : $spilt
0..($spilt - 1) | ForEach-Object -Parallel {
    $tiff = "$using:TempFolder\$($_.ToString()).tiff"
    $a = ([math]::Round($using:pages / $using:spilt * $_) + 1).ToString()
    $b = [math]::Round($using:pages / $using:spilt * ($_ + 1)).ToString()
    "converting to tiff $_"
    gswin64c.exe -q -dNOPAUSE -sDEVICE=tiffg4 "-dFirstPage=$a" "-dLastPage=$b" "-sOutputFile=$tiff" -r300 $using:pdf -c quit
    "OCRing $_"
    tesseract.exe $tiff "$using:TempFolder\$($_.ToString())" -l eng -c textonly_pdf=1 pdf | Out-Null
}
$pdfs = @()
for ($i = 0; $i -lt $spilt; $i++) {
    $pdfs += "$TempFolder\$i.pdf"
}
pdftk.exe $pdfs cat output "$TempFolder\out1.pdf"
pdftk.exe "$TempFolder\out1.pdf" multibackground $pdf output "$TempFolder\out2.pdf"
pdftk.exe $pdf dump_data_utf8 output - | pdftk.exe "$TempFolder\out2.pdf" update_info_utf8 - output "$($pdf.Remove($pdf.Length - 4))_OCR.pdf"
Remove-Item $TempFolder -Force -Recurse