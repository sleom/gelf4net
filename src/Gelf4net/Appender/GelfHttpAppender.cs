﻿using log4net.Appender;
using log4net.Core;
using System;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace gelf4net.Appender
{
    public class GelfHttpAppender : AppenderSkeleton
    {
        private readonly HttpClient _httpClient;

        private Uri _baseUrl;

        private TimeSpan _timeout;

        public string Url { get; set; }

        public string User { get; set; }

        public string Password { get; set; }

        public int Timeout { get; set; }

        public GelfHttpAppender()
        {
            _httpClient = new HttpClient();
        }

        public override void ActivateOptions()
        {
            base.ActivateOptions();

            _baseUrl = new Uri(Url);

            _httpClient.DefaultRequestHeaders.ExpectContinue = false;

            if (!string.IsNullOrEmpty(User) && !string.IsNullOrEmpty(Password))
            {
                var byteArray = Encoding.ASCII.GetBytes(User + ":" + Password);
                _httpClient.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", Convert.ToBase64String(byteArray));
            }

            _timeout = TimeSpan.FromMilliseconds(Timeout == default(int) ? 5000 : Timeout);
        }

        protected override void Append(LoggingEvent loggingEvent)
        {
            var tokenSource = new CancellationTokenSource(_timeout);
            Task.Run(async () =>
            {
                try
                {
                    var payload = this.RenderLoggingEvent(loggingEvent);
                    var content = new StringContent(payload, System.Text.Encoding.UTF8, "application/json");
                    await _httpClient.PostAsync(_baseUrl, content, tokenSource.Token);
                }
                catch (Exception ex)
                {
                    this.ErrorHandler.Error("Unable to send logging event to remote host " + this.Url, ex);
                }
            }, tokenSource.Token);
        }
    }
}
