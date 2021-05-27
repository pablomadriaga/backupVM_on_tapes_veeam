#Servidor de base de datos de Veeam
$VeeamSqlServer = 'fqdn del server'

$DataBase = 'Base de datos'

#Directorio de scripts SQL
$ScriptDir = "C:\Scripts\Veeam"

#Directorio para guardar los reportes
$ReportDir = "$ScriptDir\Reports"

#Logs
$Logfile = "$ScriptDir\Logs\reporte.log"


#Funcion para escribir logs
Function LogWrite
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}


#Requisito tener instalado el modulo de SqlServer
Import-Module SqlServer

#Obtenemos la fecha para usarla en el nombre del reporte luego
$date = Get-Date -format "yyyyMMdd-HHmmss"


#Credenciales para la conexion a la base de datos
#$userPass = Get-Credential -Credential VeeamBAR


#Conexion a la base y ejecucion del script SQL
$TapeInventory = Invoke-Sqlcmd -InputFile $ScriptDir\VeeamTapeInventory.sql -ServerInstance $VeeamSqlServer -Database $DataBase -Username "Usuario" -Password "Contraseña"
#$TapeInventory #| Where-Object {$_.Table_name -like "*tape*"} | Sort-Object -Property table_name

#Expresion regular para buscar la fecha
$regEx = [regex]'(?i)[d]+\d{4}[-]+\d{2}[-]+\d{2}' #+\d{2}[e]+\d{2}



######### Parte para despejar la fecha desde el nombre del archivo ##########

#se crea colección vacia
$valor = @{}


#Se recorre los valores de la consulta Sql
$TapeInventory | ForEach-Object { 

    #Desde el nombre de archivo filtamos la fecha, con la expresion regular declarada arriba
    $string = $_.File_Name
    $match = $regEx.Match($string)
    if ($match.Success) {
        $valor = $match.Value-replace('d','') 
        
    }
    else {
        $valor = "sin datos"
    }
    
    #Agregamos los datos obtenidos
    Add-Member -InputObject $_ -NotePropertyName "Date" -NotePropertyValue $valor
}


$TapeInventory | Export-Csv $ReportDir\VeeamTapeInventory_$Date.csv -NoTypeInformation
LogWrite "Tape inventory has been exported to: "
LogWrite "$ReportDir\VeeamTapeInventory_$Date.csv"