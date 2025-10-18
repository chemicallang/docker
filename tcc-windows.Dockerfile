### EXPERIMENTAL IMAGE, UNTESTED AND MAY NOT WORK AS EXPECTED ###

# Use the smallest possible Windows base image
FROM mcr.microsoft.com/windows/nanoserver:ltsc2022

# Set working directory
WORKDIR C:\opt

# Download and extract your zip file (update the path to Windows x64 zip)
ADD https://github.com/chemicallang/chemical/releases/download/v0.0.21/windows-x64-tcc.zip C:\opt\windows-x64-tcc.zip

# Extract the archive using PowerShell's built-in Expand-Archive
RUN powershell -Command "Expand-Archive -Path 'C:\\opt\\windows-x64-tcc.zip' -DestinationPath 'C:\\opt' ; Remove-Item 'C:\\opt\\windows-x64-tcc.zip'"

# Add the compiler directory to PATH
ENV PATH="C:\\opt\\windows-x64-tcc;${PATH}"

# Default command
CMD ["chemical.exe", "--version"]