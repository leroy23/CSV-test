
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') 				| out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')  				| out-null
[System.Reflection.Assembly]::LoadWithPartialName('PresentationCore')      				| out-null
[System.Reflection.Assembly]::LoadFrom('assembly\MahApps.Metro.dll')       				| out-null
[System.Reflection.Assembly]::LoadFrom('assembly\System.Windows.Interactivity.dll') 	| out-null
[System.Windows.Forms.Application]::EnableVisualStyles()

 #                     LOAD FUNCTION                         
##############################################################
function LoadXml ($Global:filename)
{
    $XamlLoader=(New-Object System.Xml.XmlDocument)
    $XamlLoader.Load($filename)
    return $XamlLoader
}

# Load MainWindow
$XamlMainWindow=LoadXml(".\Main.xaml")
$Reader=(New-Object System.Xml.XmlNodeReader $XamlMainWindow)
$Form=[Windows.Markup.XamlReader]::Load($Reader)

# Load CustomDialog
$xamlDialog  = LoadXml(".\selectHeaders.xaml")
$read=(New-Object System.Xml.XmlNodeReader $xamlDialog)
$DialogForm=[Windows.Markup.XamlReader]::Load( $read )

# bind main form with custom
$CustomDialog         = [MahApps.Metro.Controls.Dialogs.CustomDialog]::new($Form)
$CustomDialog.AddChild($DialogForm)
$settings             = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()
$settings.ColorScheme = [MahApps.Metro.Controls.Dialogs.MetroDialogColorScheme]::Theme



#                CONTROL INITIALIZATION                      
##############################################################

#main
$Source    = $Form.FindName("Destination")
$ItemsList = $Form.FindName("ItemsList")
$Source.AllowDrop = $True

#custom
$cdpath = $DialogForm.FindName("xpath")
$cdcmbHeaders  = $DialogForm.FindName("xHeaders")
$cdbtnHeaders = $DialogForm.FindName("btnHeaders")

# dialog error                                               
$ok = [MahApps.Metro.Controls.Dialogs.MessageDialogStyle]::Affirmative 
$Button_Style = [MahApps.Metro.Controls.Dialogs.MetroDialogSettings]::new()

$Button_Style.AffirmativeButtonText = "OK"

#                VAR INIZ.                                   
##############################################################

class Itempxi {
    [int]$lid
    [Collections.Generic.List[String]] $headers
    [string]$selheader
    [string]$xpath
    [string]$CSVname;
}
$observableCollection = New-Object System.Collections.ObjectModel.ObservableCollection[Itempxi]
$ItemsList.ItemsSource = $observableCollection

#                FUNCTIONS                                   
##############################################################
Function SelectHeaders($inpath){
    $FileContent = Get-Content $inpath
$del1 = Select-String -InputObject $FileContent -Pattern ";" -AllMatches
$del2 = Select-String -InputObject $FileContent -Pattern "," -AllMatches
if($del1.Matches.Count -ge $del2.Matches.Count){
       $old = import-csv -LiteralPath $inpath -Delimiter ";"
}
else {
    $old = import-csv -LiteralPath $inpath -Delimiter ","
}


    $headers = ((($old[0] | out-string) -split '\n')[1] -split '\s+').Split("\s+")
    return $headers
    }

function CreateCSV() {
$inpath = $cdpath.Text
    $addCSV = New-Object Itempxi
    Write-Host "Is empty: " $addCSV
    #
    $addCSV.lid = $observableCollection.Count + 1
    $addCSV.xpath = $inpath;
    Write-Host "Is path: " $inpath " = " $addCSV.xpath
    #
    
   $addCSV.headers = $cdcmbHeaders.ItemsSource;
   Write-Host "Is headers: " $cdcmbHeaders.ItemsSource " = " $addCSV.headers
   #
$CSVname = [string]$addCSV.lid + "_" + $inpath.Substring($inpath.LastIndexOf("\") + 1)
    $addCSV.CSVname = $CSVname
    Write-Host "Is usercontrol: "  $CSVname  " = " $addCSV.CSVname
    #
    $selectedItem = $cdcmbHeaders.SelectedValue

    if ($cdcmbHeaders.SelectedValue -notlike $null) {
        $addCSV.selheader = $selectedItem
        Write-Host "Is selecteditem-header: " $selectedItem " = " $addCSV.selheader
        #
        $observableCollection.Add($addCSV)
    }
    else {
        Write-Host "Nessun CSV verrà importato!"
    }
    $CustomDialog.RequestCloseAsync() 
}
Function TestCSV([string]$inpath){

    $exist = $false
    foreach ($item in $observableCollection) {
         $exist = $false
        if($item.xpath -like $inpath){
            $exist = $true
        }
    }
       if(($inpath.Substring($inpath.LastIndexOf(".") + 1) -like "csv") -and ($exist -eq $false)){ 
        $cdcmbHeaders.ItemsSource = SelectHeaders($inpath)
        $cdpath.Text = $inpath
[MahApps.Metro.Controls.Dialogs.DialogManager]::ShowMetroDialogAsync($Form, $CustomDialog, $settings)

       } 
    elseif (($inpath.Substring($inpath.LastIndexOf(".") + 1) -like "csv") -and ($exist -eq $true) ) {
 [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Errore","Il Path '" + $inpath + "' da te inserito fa riferimento CSV già inserito",$ok, $Button_Style)     

    }
    else {
  [MahApps.Metro.Controls.Dialogs.DialogManager]::ShowModalMessageExternal($Form,"Errore","Il Path '" + $inpath + "' da te inserito non fa riferimento a nessun CSV",$ok, $Button_Style)  
    
    }

}

$Source.Add_PreviewDragOver({
    [System.Object]$script:sender = $args[0]
    [System.Windows.DragEventArgs]$e = $args[1]

    $e.Effects = [System.Windows.DragDropEffects]::Move
    $e.Handled = $true
})


$Source.Add_Drop({

    [System.Object]$script:sender = $args[0]
    [System.Windows.DragEventArgs]$e = $args[1]

    If($e.Data.GetDataPresent([System.Windows.DataFormats]::FileDrop)){

        $Script:Files =  $e.Data.GetData([System.Windows.DataFormats]::FileDrop)

        Foreach($file in $Files){
            If((Get-Item $file) -is [System.IO.DirectoryInfo]){
                $dirs =  Get-ChildItem -Path $file -Force -Recurse 
                write-host "Paths : " + $dirs
                foreach($path in $dirs){
                  If((Get-Item $path) -isnot [System.IO.DirectoryInfo]){
                  TestCSV($path)
                  }
            }
        }
        else {
            TestCSV($file)
             }
        }
    }

})
$cdbtnHeaders.add_Click({ CreateCSV })
$Form.ShowDialog() | Out-Null

