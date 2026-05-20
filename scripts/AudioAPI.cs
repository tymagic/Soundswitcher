using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace SoundSwitcher
{
    [ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
    public class MMDeviceEnumerator { }

    public enum EDataFlow
    {
        eRender = 0,
        eCapture = 1,
        eAll = 2
    }

    public enum ERole
    {
        eConsole = 0,
        eMultimedia = 1,
        eCommunications = 2
    }

    [Flags]
    public enum DEVICE_STATE : uint
    {
        ACTIVE = 0x00000001,
        DISABLED = 0x00000002,
        NOTPRESENT = 0x00000004,
        UNPLUGGED = 0x00000008,
        ALL = 0x0000000F
    }

    [Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceEnumerator
    {
        int EnumAudioEndpoints(EDataFlow dataFlow, DEVICE_STATE dwStateMask, out IMMDeviceCollection ppDevices);
        int GetDefaultAudioEndpoint(EDataFlow dataFlow, ERole role, out IMMDevice ppEndpoint);
        int GetDevice([MarshalAs(UnmanagedType.LPWStr)] string pwstrId, out IMMDevice ppDevice);
        int RegisterEndpointNotificationCallback(IntPtr pClient);
        int UnregisterEndpointNotificationCallback(IntPtr pClient);
    }

    [Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDeviceCollection
    {
        int GetCount(out uint pcDevices);
        int Item(uint nDevice, out IMMDevice ppDevice);
    }

    [Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IMMDevice
    {
        int Activate(ref Guid iid, uint dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
        int OpenPropertyStore(uint stgmAccess, out IPropertyStore ppProperties);
        int GetId([MarshalAs(UnmanagedType.LPWStr)] out string ppstrId);
        int GetState(out DEVICE_STATE pdwState);
    }

    [Guid("886D8EEB-8CF2-4446-8D02-CDBA1DBDCF99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPropertyStore
    {
        int GetCount(out uint cProps);
        int GetAt(uint iProp, out PROPERTYKEY pKey);
        int GetValue(ref PROPERTYKEY key, out PROPVARIANT pv);
        int SetValue(ref PROPERTYKEY key, ref PROPVARIANT propvar);
        int Commit();
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct PROPERTYKEY
    {
        public Guid fmtid;
        public uint pid;
    }

    [StructLayout(LayoutKind.Explicit)]
    public struct PROPVARIANT
    {
        [FieldOffset(0)] public ushort vt;
        [FieldOffset(2)] public ushort wReserved1;
        [FieldOffset(4)] public ushort wReserved2;
        [FieldOffset(6)] public ushort wReserved3;
        [FieldOffset(8)] public IntPtr pwszVal;
        [FieldOffset(8)] public IntPtr blobVal;
    }

    [ComImport, Guid("870AF99C-171D-4F9E-AF0D-E63DF40C2BC9")]
    public class CPolicyConfigClient { }

    [Guid("F8679F50-850A-41CF-9C72-430F290290C8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    public interface IPolicyConfig
    {
        int GetMixFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr ppFormat);
        int GetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, int bDefault, IntPtr ppFormat);
        int ResetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName);
        int SetDeviceFormat([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pEndpointFormat, IntPtr mixFormat);
        int GetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, int bDefault, IntPtr pmftDefaultPeriod, IntPtr pmftMinimumPeriod);
        int SetProcessingPeriod([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pmftMinimumPeriod);
        int GetShareMode([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr pMode);
        int SetShareMode([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, IntPtr mode);
        int GetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, ref PROPERTYKEY key, out PROPVARIANT pv);
        int SetPropertyValue([MarshalAs(UnmanagedType.LPWStr)] string pszDeviceName, ref PROPERTYKEY key, ref PROPVARIANT pv);
        int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string wszDeviceId, ERole eRole);
        int SetEndpointVisibility([MarshalAs(UnmanagedType.LPWStr)] string wszDeviceId, int bVisible);
    }

    public class AudioDeviceInfo
    {
        public string Id { get; set; }
        public string Name { get; set; }
        public string Type { get; set; }
        public bool IsDefault { get; set; }
    }

    public static class AudioDeviceManager
    {
        private static readonly Guid PKEY_Device_FriendlyName =
            new Guid("{A45C254E-DF1C-4EFD-8020-67D146A850E0}");

        private static string GetDeviceName(IMMDevice device)
        {
            try
            {
                IPropertyStore store;
                device.OpenPropertyStore(0, out store);
                PROPERTYKEY key = new PROPERTYKEY
                {
                    fmtid = PKEY_Device_FriendlyName,
                    pid = 14
                };
                PROPVARIANT pv;
                store.GetValue(ref key, out pv);
                if (pv.pwszVal != IntPtr.Zero)
                {
                    return Marshal.PtrToStringUni(pv.pwszVal);
                }
            }
            catch { }
            return "Unknown Device";
        }

        public static List<AudioDeviceInfo> GetDevices(EDataFlow flow)
        {
            var devices = new List<AudioDeviceInfo>();
            try
            {
                var enumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
                IMMDeviceCollection collection;
                enumerator.EnumAudioEndpoints(flow, DEVICE_STATE.ACTIVE, out collection);
                uint count;
                collection.GetCount(out count);

                string defaultId = string.Empty;
                try
                {
                    if (flow != EDataFlow.eAll)
                    {
                        IMMDevice defaultDevice;
                        enumerator.GetDefaultAudioEndpoint(flow, ERole.eConsole, out defaultDevice);
                        defaultDevice.GetId(out defaultId);
                    }
                }
                catch { }

                string typeName = (flow == EDataFlow.eRender) ? "render" : "capture";

                for (uint i = 0; i < count; i++)
                {
                    IMMDevice device;
                    collection.Item(i, out device);
                    string deviceId;
                    device.GetId(out deviceId);
                    string name = GetDeviceName(device);
                    devices.Add(new AudioDeviceInfo
                    {
                        Id = deviceId,
                        Name = name,
                        Type = typeName,
                        IsDefault = (deviceId == defaultId)
                    });
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Error enumerating devices: " + ex.Message);
            }
            return devices;
        }

        public static bool SetDefaultEndpoint(string deviceId, ERole role)
        {
            try
            {
                var config = new CPolicyConfigClient() as IPolicyConfig;
                int hr = config.SetDefaultEndpoint(deviceId, role);
                return hr >= 0;
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("Error setting default endpoint: " + ex.Message);
                return false;
            }
        }

        public static AudioDeviceInfo GetDefaultDevice(EDataFlow flow)
        {
            try
            {
                var enumerator = new MMDeviceEnumerator() as IMMDeviceEnumerator;
                IMMDevice device;
                enumerator.GetDefaultAudioEndpoint(flow, ERole.eConsole, out device);
                string id;
                device.GetId(out id);
                string name = GetDeviceName(device);
                return new AudioDeviceInfo
                {
                    Id = id,
                    Name = name,
                    Type = (flow == EDataFlow.eRender) ? "render" : "capture",
                    IsDefault = true
                };
            }
            catch { return null; }
        }
    }
}
