using System.Threading;
using System.Windows;

namespace SnipKey.WinApp;

internal static class Program
{
    [STAThread]
    public static void Main()
    {
        using var mutex = new Mutex(initiallyOwned: true, name: @"Local\SnipKey.Windows", createdNew: out var createdNew);
        if (!createdNew)
        {
            return;
        }

        System.Windows.Forms.Application.EnableVisualStyles();
        System.Windows.Forms.Application.SetCompatibleTextRenderingDefault(false);

        var application = new Application
        {
            ShutdownMode = ShutdownMode.OnExplicitShutdown
        };

        using var controller = new AppController();
        application.Startup += (_, _) => controller.Start();
        application.Exit += (_, _) => controller.Dispose();
        application.Run();
    }
}
