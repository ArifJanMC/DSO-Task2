#!/usr/bin/env python3
"""
Скрипт для генерации аномальных запросов к Nginx
для тестирования системы обнаружения аномалий
"""

import requests
import time
import random
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse
import json
from datetime import datetime

class AnomalyGenerator:
    def __init__(self, target_url="http://localhost"):
        self.target_url = target_url
        self.session = requests.Session()
        self.results = {
            "404_errors": 0,
            "403_errors": 0,
            "rate_limit_hits": 0,
            "sql_injections": 0,
            "xss_attempts": 0,
            "suspicious_agents": 0,
            "total_requests": 0
        }
        
    def generate_404_errors(self, count=50):
        """Генерация множественных 404 ошибок (перебор адресов)"""
        print(f"\n[{datetime.now()}] Generating {count} 404 errors...")
        
        paths = [
            "/admin", "/wp-admin", "/phpmyadmin", "/backup",
            "/.git", "/.env", "/config.php", "/database.yml",
            "/secret", "/private", "/hidden", "/test",
            f"/random_{random.randint(1000,9999)}"
        ]
        
        for i in range(count):
            path = random.choice(paths) + f"/{random.randint(1,1000)}"
            try:
                response = self.session.get(f"{self.target_url}{path}")
                if response.status_code == 404:
                    self.results["404_errors"] += 1
                self.results["total_requests"] += 1
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(random.uniform(0.1, 0.3))
            
    def generate_403_errors(self, count=30):
        """Генерация множественных 403 ошибок"""
        print(f"\n[{datetime.now()}] Generating {count} 403 errors...")
        
        forbidden_paths = [
            "/.htaccess", "/.htpasswd", "/cgi-bin/", 
            "/.ssh/id_rsa", "/etc/passwd", "/var/log/",
            "/../../../etc/passwd", "/admin/../../../"
        ]
        
        for i in range(count):
            path = random.choice(forbidden_paths)
            try:
                response = self.session.get(f"{self.target_url}{path}")
                if response.status_code == 403:
                    self.results["403_errors"] += 1
                self.results["total_requests"] += 1
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(random.uniform(0.1, 0.2))
            
    def generate_rate_limit_test(self, requests_count=100):
        """Генерация множественных запросов с одного IP"""
        print(f"\n[{datetime.now()}] Generating {requests_count} rapid requests...")
        
        def rapid_request():
            try:
                response = self.session.get(f"{self.target_url}/api/books")
                if response.status_code == 429:
                    self.results["rate_limit_hits"] += 1
                self.results["total_requests"] += 1
                return response.status_code
            except Exception as e:
                return None
                
        with ThreadPoolExecutor(max_workers=10) as executor:
            futures = []
            for i in range(requests_count):
                futures.append(executor.submit(rapid_request))
                time.sleep(0.05)  # 20 requests per second
                
            for future in as_completed(futures):
                result = future.result()
                
    def generate_suspicious_user_agents(self, count=20):
        """Генерация запросов с подозрительными User-Agent"""
        print(f"\n[{datetime.now()}] Generating {count} suspicious User-Agent requests...")
        
        suspicious_agents = [
            "sqlmap/1.3.11#stable (http://sqlmap.org)",
            "nikto/2.1.5",
            "masscan/1.0",
            "Mozilla/5.0 (compatible; Nmap Scripting Engine)",
            "WPScan v3.8.10",
            "python-requests/2.22.0",
            "",  # Empty user agent
            "-",  # Dash user agent
            "bot", "crawler", "spider",
            "curl/7.64.1",
            "wget/1.20.3",
            "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1)"  # Old IE
        ]
        
        for i in range(count):
            headers = {"User-Agent": random.choice(suspicious_agents)}
            try:
                response = self.session.get(f"{self.target_url}/", headers=headers)
                if response.status_code == 403:
                    self.results["suspicious_agents"] += 1
                self.results["total_requests"] += 1
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(random.uniform(0.2, 0.5))
            
    def generate_sql_injection_attempts(self, count=30):
        """Генерация попыток SQL-инъекций"""
        print(f"\n[{datetime.now()}] Generating {count} SQL injection attempts...")
        
        sql_payloads = [
            "' OR '1'='1",
            "1' UNION SELECT * FROM users--",
            "admin' DROP TABLE users--",
            "1' AND (SELECT * FROM (SELECT(SLEEP(5)))a)--",
            "' OR 1=1#",
            "1' UNION SELECT NULL,version()--",
            "'; INSERT INTO users VALUES ('hacker', 'password')--",
            "1' AND benchmark(10000000,MD5(1))--",
            "' UNION ALL SELECT NULL,NULL,NULL--",
            "1' OR '1'='1' /*"
        ]
        
        for i in range(count):
            payload = random.choice(sql_payloads)
            paths = [
                f"/api/books?id={payload}",
                f"/api/authors?name={payload}",
                f"/search?q={payload}",
                f"/login?username={payload}"
            ]
            
            try:
                response = self.session.get(f"{self.target_url}{random.choice(paths)}")
                if response.status_code in [403, 400]:
                    self.results["sql_injections"] += 1
                self.results["total_requests"] += 1
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(random.uniform(0.3, 0.7))
            
    def generate_xss_attempts(self, count=25):
        """Генерация попыток XSS-атак"""
        print(f"\n[{datetime.now()}] Generating {count} XSS attempts...")
        
        xss_payloads = [
            "<script>alert('XSS')</script>",
            "<img src=x onerror=alert('XSS')>",
            "<iframe src='javascript:alert(\"XSS\")'></iframe>",
            "<body onload=alert('XSS')>",
            "<input type='text' value='<script>alert(\"XSS\")</script>'>",
            "javascript:alert('XSS')",
            "<svg/onload=alert('XSS')>",
            "<object data='javascript:alert(\"XSS\")'></object>",
            "<embed src='javascript:alert(\"XSS\")'>",
            "';alert(String.fromCharCode(88,83,83))//';alert(String.fromCharCode(88,83,83))//"
        ]
        
        for i in range(count):
            payload = random.choice(xss_payloads)
            paths = [
                f"/search?q={payload}",
                f"/api/reviews",
                f"/comment?text={payload}",
                f"/profile?name={payload}"
            ]
            
            try:
                if "/api/reviews" in random.choice(paths):
                    # POST request for reviews
                    data = {
                        "comment": payload,
                        "rating": 5,
                        "reviewer_name": "Test",
                        "book_id": 1
                    }
                    response = self.session.post(
                        f"{self.target_url}/api/reviews",
                        json=data
                    )
                else:
                    response = self.session.get(f"{self.target_url}{random.choice(paths)}")
                    
                if response.status_code in [403, 400]:
                    self.results["xss_attempts"] += 1
                self.results["total_requests"] += 1
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(random.uniform(0.2, 0.5))
            
    def generate_path_traversal_attempts(self, count=15):
        """Генерация попыток path traversal"""
        print(f"\n[{datetime.now()}] Generating {count} path traversal attempts...")
        
        traversal_payloads = [
            "../../../etc/passwd",
            "..\\..\\..\\windows\\system32\\config\\sam",
            "....//....//....//etc/passwd",
            "%2e%2e%2f%2e%2e%2f%2e%2e%2fetc%2fpasswd",
            "..%252f..%252f..%252fetc%252fpasswd",
            "..%c0%af..%c0%af..%c0%afetc%c0%afpasswd"
        ]
        
        for i in range(count):
            payload = random.choice(traversal_payloads)
            try:
                response = self.session.get(f"{self.target_url}/files/{payload}")
                self.results["total_requests"] += 1
            except Exception as e:
                print(f"Error: {e}")
            time.sleep(random.uniform(0.3, 0.6))
            
    def generate_all_anomalies(self):
        """Генерация всех типов аномалий"""
        print(f"\n{'='*60}")
        print(f"Starting anomaly generation at {datetime.now()}")
        print(f"Target: {self.target_url}")
        print(f"{'='*60}")
        
        # Запуск всех генераторов
        self.generate_404_errors(50)
        self.generate_403_errors(30)
        self.generate_suspicious_user_agents(20)
        self.generate_sql_injection_attempts(30)
        self.generate_xss_attempts(25)
        self.generate_path_traversal_attempts(15)
        self.generate_rate_limit_test(100)
        
        # Вывод результатов
        print(f"\n{'='*60}")
        print(f"Anomaly generation completed at {datetime.now()}")
        print(f"{'='*60}")
        print("\nResults:")
        print(f"Total requests sent: {self.results['total_requests']}")
        print(f"404 errors generated: {self.results['404_errors']}")
        print(f"403 errors generated: {self.results['403_errors']}")
        print(f"Rate limit hits: {self.results['rate_limit_hits']}")
        print(f"SQL injection blocks: {self.results['sql_injections']}")
        print(f"XSS attempt blocks: {self.results['xss_attempts']}")
        print(f"Suspicious agent blocks: {self.results['suspicious_agents']}")
        
        # Сохранение результатов
        with open(f"anomaly_results_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", "w") as f:
            json.dump({
                "timestamp": datetime.now().isoformat(),
                "target": self.target_url,
                "results": self.results
            }, f, indent=2)

def main():
    parser = argparse.ArgumentParser(description="Generate anomalous requests for testing")
    parser.add_argument("--url", default="http://localhost", help="Target URL")
    parser.add_argument("--type", choices=[
        "all", "404", "403", "rate", "agent", "sql", "xss", "traversal"
    ], default="all", help="Type of anomaly to generate")
    
    args = parser.parse_args()
    
    generator = AnomalyGenerator(args.url)
    
    if args.type == "all":
        generator.generate_all_anomalies()
    elif args.type == "404":
        generator.generate_404_errors()
    elif args.type == "403":
        generator.generate_403_errors()
    elif args.type == "rate":
        generator.generate_rate_limit_test()
    elif args.type == "agent":
        generator.generate_suspicious_user_agents()
    elif args.type == "sql":
        generator.generate_sql_injection_attempts()
    elif args.type == "xss":
        generator.generate_xss_attempts()
    elif args.type == "traversal":
        generator.generate_path_traversal_attempts()

if __name__ == "__main__":
    main()